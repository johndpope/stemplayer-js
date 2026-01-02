//! Flutter API - functions exposed to Dart via flutter_rust_bridge

use crate::database::PaletteDatabase;
use crate::fingerprint::{AudioFingerprint, Fingerprinter};
use crate::midi::{export_matches_to_csv, export_matches_to_markers, export_matches_to_midi, MidiExportConfig};
use crate::search::SearchEngine;
use crate::{MatchResult, SoundRecord};
use std::sync::Mutex;

/// Global database instance (lazily initialized)
static DATABASE: std::sync::OnceLock<Mutex<Option<PaletteDatabase>>> = std::sync::OnceLock::new();

fn get_db() -> &'static Mutex<Option<PaletteDatabase>> {
    DATABASE.get_or_init(|| Mutex::new(None))
}

/// Initialize the audio palette database
#[flutter_rust_bridge::frb(sync)]
pub fn init_database(db_path: String) -> Result<(), String> {
    let db = PaletteDatabase::open(&db_path).map_err(|e| e.to_string())?;
    let mut guard = get_db().lock().unwrap();
    *guard = Some(db);
    Ok(())
}

/// Add a sound file to the database
pub fn add_sound(filepath: String) -> Result<i64, String> {
    let guard = get_db().lock().unwrap();
    let db = guard.as_ref().ok_or("Database not initialized")?;

    // Load audio and extract metadata
    let audio = crate::audio::AudioData::load(&filepath).map_err(|e| e.to_string())?;
    let filename = std::path::Path::new(&filepath)
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| filepath.clone());

    let sound_id = db.add_sound(
        &filepath,
        &filename,
        audio.duration,
        audio.sample_rate,
        audio.channels as u16,
        "unknown",
    ).map_err(|e| e.to_string())?;

    // Extract fingerprint
    let fingerprinter = Fingerprinter::default();
    let fp = fingerprinter.extract(&audio).map_err(|e| e.to_string())?;
    db.store_fingerprint(sound_id, &fp).map_err(|e| e.to_string())?;

    Ok(sound_id)
}

/// Get all sounds in the database
pub fn get_all_sounds() -> Result<Vec<SoundRecord>, String> {
    let guard = get_db().lock().unwrap();
    let db = guard.as_ref().ok_or("Database not initialized")?;
    db.get_all_sounds().map_err(|e| e.to_string())
}

/// Get sound count
#[flutter_rust_bridge::frb(sync)]
pub fn get_sound_count() -> Result<i64, String> {
    let guard = get_db().lock().unwrap();
    let db = guard.as_ref().ok_or("Database not initialized")?;
    db.count().map_err(|e| e.to_string())
}

/// Search sounds by filename
pub fn search_sounds(query: String) -> Result<Vec<SoundRecord>, String> {
    let guard = get_db().lock().unwrap();
    let db = guard.as_ref().ok_or("Database not initialized")?;
    db.search(&query).map_err(|e| e.to_string())
}

/// Find similar sounds to a query file
pub fn find_similar(query_path: String, threshold: f64, max_results: usize) -> Result<Vec<MatchResult>, String> {
    let guard = get_db().lock().unwrap();
    let db = guard.as_ref().ok_or("Database not initialized")?;

    let engine = SearchEngine::new();
    let query_fp = engine.fingerprint_file(&query_path).map_err(|e| e.to_string())?;
    engine.find_similar(&query_fp, db, threshold, max_results).map_err(|e| e.to_string())
}

/// Find similar sounds with segment matching (returns exact time ranges)
pub fn find_similar_with_segments(
    query_path: String,
    threshold: f64,
    max_results: usize,
) -> Result<Vec<MatchResult>, String> {
    let guard = get_db().lock().unwrap();
    let db = guard.as_ref().ok_or("Database not initialized")?;

    let engine = SearchEngine::new();
    let query_fp = engine.fingerprint_file(&query_path).map_err(|e| e.to_string())?;
    engine.find_similar_with_segments(&query_fp, db, threshold, max_results).map_err(|e| e.to_string())
}

/// Find similar sounds from audio samples (for selection-based search)
pub fn find_similar_from_samples(
    samples: Vec<f32>,
    sample_rate: u32,
    threshold: f64,
    max_results: usize,
) -> Result<Vec<MatchResult>, String> {
    let guard = get_db().lock().unwrap();
    let db = guard.as_ref().ok_or("Database not initialized")?;

    let engine = SearchEngine::new();
    let query_fp = engine.fingerprint_samples(&samples, sample_rate).map_err(|e| e.to_string())?;
    engine.find_similar_with_segments(&query_fp, db, threshold, max_results).map_err(|e| e.to_string())
}

/// Export match results to MIDI file
pub fn export_to_midi(
    matches: Vec<MatchResult>,
    output_path: String,
    tempo_bpm: u32,
    base_note: u8,
) -> Result<(), String> {
    let config = MidiExportConfig {
        tempo_bpm,
        base_note,
        ticks_per_beat: 480,
    };
    export_matches_to_midi(&matches, &output_path, &config).map_err(|e| e.to_string())
}

/// Export match results to CSV file
pub fn export_to_csv(matches: Vec<MatchResult>, output_path: String) -> Result<(), String> {
    export_matches_to_csv(&matches, &output_path).map_err(|e| e.to_string())
}

/// Export match results to markers file
pub fn export_to_markers(matches: Vec<MatchResult>, output_path: String) -> Result<(), String> {
    export_matches_to_markers(&matches, &output_path).map_err(|e| e.to_string())
}

/// Remove a sound from the database
pub fn remove_sound(sound_id: i64) -> Result<(), String> {
    let guard = get_db().lock().unwrap();
    let db = guard.as_ref().ok_or("Database not initialized")?;
    db.remove_sound(sound_id).map_err(|e| e.to_string())
}

/// Extract audio fingerprint from file (for debugging/display)
pub fn get_fingerprint(filepath: String) -> Result<AudioFingerprintInfo, String> {
    let fingerprinter = Fingerprinter::default();
    let fp = fingerprinter.extract_from_file(&filepath).map_err(|e| e.to_string())?;

    Ok(AudioFingerprintInfo {
        duration: fp.duration,
        spectral_centroid: fp.spectral_centroid,
        spectral_bandwidth: fp.spectral_bandwidth,
        spectral_rolloff: fp.spectral_rolloff,
        mfcc_mean: fp.mfcc_mean,
        mfcc_std: fp.mfcc_std,
    })
}

/// Simplified fingerprint info for Flutter
#[derive(Debug, Clone)]
pub struct AudioFingerprintInfo {
    pub duration: f64,
    pub spectral_centroid: f64,
    pub spectral_bandwidth: f64,
    pub spectral_rolloff: f64,
    pub mfcc_mean: Vec<f64>,
    pub mfcc_std: Vec<f64>,
}

/// Compute similarity between two fingerprints (0-100)
#[flutter_rust_bridge::frb(sync)]
pub fn compute_similarity(fp1_path: String, fp2_path: String) -> Result<f64, String> {
    let fingerprinter = Fingerprinter::default();
    let fp1 = fingerprinter.extract_from_file(&fp1_path).map_err(|e| e.to_string())?;
    let fp2 = fingerprinter.extract_from_file(&fp2_path).map_err(|e| e.to_string())?;
    Ok(fp1.similarity(&fp2))
}
