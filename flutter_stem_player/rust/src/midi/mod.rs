//! MIDI export for match results

use crate::{AudioPaletteError, MatchResult, Result};
use midly::{Format, Header, MidiMessage, Smf, Track, TrackEvent, TrackEventKind};
use std::fs::File;
use std::io::Write;
use std::path::Path;

/// MIDI export configuration
#[derive(Debug, Clone)]
pub struct MidiExportConfig {
    pub tempo_bpm: u32,
    pub base_note: u8,
    pub ticks_per_beat: u16,
}

impl Default for MidiExportConfig {
    fn default() -> Self {
        MidiExportConfig {
            tempo_bpm: 120,
            base_note: 60, // Middle C
            ticks_per_beat: 480,
        }
    }
}

/// Export match results to MIDI file
pub fn export_matches_to_midi<P: AsRef<Path>>(
    matches: &[MatchResult],
    output_path: P,
    config: &MidiExportConfig,
) -> Result<()> {
    if matches.is_empty() {
        return Err(AudioPaletteError::MidiError("No matches to export".to_string()));
    }

    let header = Header::new(
        Format::Parallel,
        midly::Timing::Metrical(config.ticks_per_beat.into()),
    );

    let mut tracks: Vec<Track> = Vec::new();

    // Tempo track - use static bytes to avoid lifetime issues
    let mut tempo_track = Track::new();
    let tempo_us = 60_000_000 / config.tempo_bpm; // Microseconds per beat
    tempo_track.push(TrackEvent {
        delta: 0.into(),
        kind: TrackEventKind::Meta(midly::MetaMessage::Tempo(tempo_us.into())),
    });
    tempo_track.push(TrackEvent {
        delta: 0.into(),
        kind: TrackEventKind::Meta(midly::MetaMessage::EndOfTrack),
    });
    tracks.push(tempo_track);

    // Calculate ticks per second
    let ticks_per_second = config.ticks_per_beat as f64 * config.tempo_bpm as f64 / 60.0;

    // Create a track for each match (up to 15, leaving room for tempo track)
    for (i, m) in matches.iter().take(15).enumerate() {
        let mut track = Track::new();

        // Skip track name to avoid lifetime issues with MetaMessage::TrackName
        // The MIDI file will still work correctly without track names

        // Calculate timing in ticks
        let start_ticks = (m.match_start * ticks_per_second) as u32;
        let duration_ticks = ((m.match_end - m.match_start) * ticks_per_second) as u32;
        let duration_ticks = duration_ticks.max(1);

        // Velocity based on score (40-127)
        let velocity = (40.0 + (m.score / 100.0) * 87.0) as u8;
        let velocity = velocity.clamp(40, 127);

        // Note number (each track gets different pitch)
        let note = (config.base_note + i as u8).min(127);

        // Note on
        track.push(TrackEvent {
            delta: start_ticks.into(),
            kind: TrackEventKind::Midi {
                channel: 0.into(),
                message: MidiMessage::NoteOn {
                    key: note.into(),
                    vel: velocity.into(),
                },
            },
        });

        // Note off
        track.push(TrackEvent {
            delta: duration_ticks.into(),
            kind: TrackEventKind::Midi {
                channel: 0.into(),
                message: MidiMessage::NoteOff {
                    key: note.into(),
                    vel: 0.into(),
                },
            },
        });

        // End of track
        track.push(TrackEvent {
            delta: 0.into(),
            kind: TrackEventKind::Meta(midly::MetaMessage::EndOfTrack),
        });

        tracks.push(track);
    }

    // Create SMF and write
    let smf = Smf {
        header,
        tracks,
    };

    let mut buffer = Vec::new();
    smf.write(&mut buffer)
        .map_err(|e| AudioPaletteError::MidiError(format!("Failed to write MIDI: {}", e)))?;

    let mut file = File::create(output_path)?;
    file.write_all(&buffer)?;

    Ok(())
}

/// Export match results to CSV
pub fn export_matches_to_csv<P: AsRef<Path>>(
    matches: &[MatchResult],
    output_path: P,
) -> Result<()> {
    let mut file = File::create(output_path)?;

    // Header
    writeln!(file, "Filename,Filepath,Score,Match Start (s),Match End (s),Match Duration (s),File Duration (s)")?;

    // Data rows
    for m in matches {
        writeln!(
            file,
            "{},{},{:.1},{:.3},{:.3},{:.3},{:.3}",
            m.filename,
            m.filepath,
            m.score,
            m.match_start,
            m.match_end,
            m.match_end - m.match_start,
            m.file_duration
        )?;
    }

    Ok(())
}

/// Export match results as marker/cue file
pub fn export_matches_to_markers<P: AsRef<Path>>(
    matches: &[MatchResult],
    output_path: P,
) -> Result<()> {
    let mut file = File::create(output_path)?;

    writeln!(file, "# Audio Match Markers")?;
    writeln!(file, "# Format: Start(s) | End(s) | Score | Filename")?;
    writeln!(file, "# -------------------------------------------\n")?;

    for (i, m) in matches.iter().enumerate() {
        let start_min = (m.match_start / 60.0) as u32;
        let start_sec = m.match_start % 60.0;
        let end_min = (m.match_end / 60.0) as u32;
        let end_sec = m.match_end % 60.0;

        writeln!(
            file,
            "[{:03}] {:02}:{:06.3} - {:02}:{:06.3} | {:.1}% | {}",
            i + 1, start_min, start_sec, end_min, end_sec, m.score, m.filename
        )?;
        writeln!(file, "      Path: {}\n", m.filepath)?;
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Read;
    use tempfile::NamedTempFile;

    #[test]
    fn test_csv_export() {
        let matches = vec![
            MatchResult {
                sound_id: 1,
                filepath: "/test/sound.wav".to_string(),
                filename: "sound.wav".to_string(),
                score: 85.5,
                match_start: 1.0,
                match_end: 2.5,
                file_duration: 5.0,
            }
        ];

        let temp = NamedTempFile::new().unwrap();
        export_matches_to_csv(&matches, temp.path()).unwrap();

        let mut content = String::new();
        File::open(temp.path()).unwrap().read_to_string(&mut content).unwrap();
        assert!(content.contains("sound.wav"));
        assert!(content.contains("85.5"));
    }
}
