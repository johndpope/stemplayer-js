//! Similarity search with segment matching

use crate::{MatchResult, Result, SoundRecord};
use crate::audio::AudioData;
use crate::database::PaletteDatabase;
use crate::fingerprint::{AudioFingerprint, Fingerprinter};
use rayon::prelude::*;

/// Similarity search engine
pub struct SearchEngine {
    fingerprinter: Fingerprinter,
}

impl Default for SearchEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl SearchEngine {
    pub fn new() -> Self {
        SearchEngine {
            fingerprinter: Fingerprinter::default(),
        }
    }

    /// Find similar sounds in database
    pub fn find_similar(
        &self,
        query_fp: &AudioFingerprint,
        db: &PaletteDatabase,
        threshold: f64,
        max_results: usize,
    ) -> Result<Vec<MatchResult>> {
        let fingerprints = db.get_all_fingerprints()?;

        // Step 1: Parallel fingerprint comparison (no database access)
        let mut scored: Vec<_> = fingerprints
            .par_iter()
            .filter_map(|(sound_id, fp)| {
                let score = query_fp.similarity(fp);
                if score >= threshold {
                    Some((*sound_id, score))
                } else {
                    None
                }
            })
            .collect();

        scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
        scored.truncate(max_results);

        // Step 2: Sequential database lookups for matching sounds
        let mut results = Vec::new();
        for (sound_id, score) in scored {
            if let Ok(Some(sound)) = db.get_sound(sound_id) {
                results.push(MatchResult {
                    sound_id,
                    filepath: sound.filepath.clone(),
                    filename: sound.filename.clone(),
                    score,
                    match_start: 0.0,
                    match_end: sound.duration,
                    file_duration: sound.duration,
                });
            }
        }

        Ok(results)
    }

    /// Find similar sounds with segment matching
    /// Returns exact time ranges where matches occur
    pub fn find_similar_with_segments(
        &self,
        query_fp: &AudioFingerprint,
        db: &PaletteDatabase,
        threshold: f64,
        max_results: usize,
    ) -> Result<Vec<MatchResult>> {
        // First pass: quick whole-file matching (parallel, no db access)
        let fingerprints = db.get_all_fingerprints()?;

        let mut scored: Vec<_> = fingerprints
            .par_iter()
            .filter_map(|(sound_id, fp)| {
                let score = query_fp.similarity(fp);
                // Lower threshold for initial filtering
                if score >= threshold * 0.8 {
                    Some((*sound_id, score))
                } else {
                    None
                }
            })
            .collect();

        scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
        scored.truncate(20); // Top 20 for segment matching

        // Get sound records sequentially
        let mut candidates: Vec<(SoundRecord, f64)> = Vec::new();
        for (sound_id, score) in scored {
            if let Ok(Some(sound)) = db.get_sound(sound_id) {
                candidates.push((sound, score));
            }
        }

        // Second pass: segment matching (parallel, file I/O only)
        let results: Vec<MatchResult> = candidates
            .into_par_iter()
            .filter_map(|(sound, _)| {
                self.find_best_segment(query_fp, &sound.filepath, &sound).ok()
            })
            .filter(|m| m.score >= threshold)
            .collect();

        let mut sorted: Vec<_> = results;
        sorted.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap());
        sorted.truncate(max_results);

        Ok(sorted)
    }

    /// Find the best matching segment in a file
    fn find_best_segment(
        &self,
        query_fp: &AudioFingerprint,
        filepath: &str,
        sound: &SoundRecord,
    ) -> Result<MatchResult> {
        let audio = AudioData::load(filepath)?;

        let query_duration = query_fp.duration;
        if query_duration <= 0.0 {
            return Ok(MatchResult {
                sound_id: sound.id,
                filepath: sound.filepath.clone(),
                filename: sound.filename.clone(),
                score: 0.0,
                match_start: 0.0,
                match_end: sound.duration,
                file_duration: sound.duration,
            });
        }

        // If query is longer than file, compare whole file
        if query_duration >= audio.duration {
            let fp = self.fingerprinter.extract(&audio)?;
            let score = query_fp.similarity(&fp);
            return Ok(MatchResult {
                sound_id: sound.id,
                filepath: sound.filepath.clone(),
                filename: sound.filename.clone(),
                score,
                match_start: 0.0,
                match_end: audio.duration,
                file_duration: audio.duration,
            });
        }

        // Sliding window search
        let window_samples = (query_duration * audio.sample_rate as f64) as usize;
        let hop_samples = window_samples / 4; // 75% overlap
        let max_windows = 50;

        let actual_hop = if audio.samples.len() / hop_samples > max_windows {
            (audio.samples.len() - window_samples) / max_windows
        } else {
            hop_samples
        };

        let mut best_score = 0.0;
        let mut best_start = 0.0;
        let mut best_end = query_duration;

        let mut pos = 0;
        while pos + window_samples <= audio.samples.len() {
            let segment = &audio.samples[pos..pos + window_samples];

            if let Ok(segment_fp) = self.fingerprinter.extract_from_samples(segment, audio.sample_rate) {
                let score = query_fp.similarity(&segment_fp);
                if score > best_score {
                    best_score = score;
                    best_start = pos as f64 / audio.sample_rate as f64;
                    best_end = (pos + window_samples) as f64 / audio.sample_rate as f64;
                }
            }

            pos += actual_hop;
        }

        Ok(MatchResult {
            sound_id: sound.id,
            filepath: sound.filepath.clone(),
            filename: sound.filename.clone(),
            score: best_score,
            match_start: best_start,
            match_end: best_end,
            file_duration: audio.duration,
        })
    }

    /// Fingerprint audio from file
    pub fn fingerprint_file(&self, filepath: &str) -> Result<AudioFingerprint> {
        self.fingerprinter.extract_from_file(filepath)
    }

    /// Fingerprint audio from samples
    pub fn fingerprint_samples(&self, samples: &[f32], sample_rate: u32) -> Result<AudioFingerprint> {
        self.fingerprinter.extract_from_samples(samples, sample_rate)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_search_engine() {
        let engine = SearchEngine::new();
        // Basic instantiation test
        assert!(true);
    }
}
