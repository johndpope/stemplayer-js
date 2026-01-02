//! Audio Palette - Rust audio analysis library for Flutter
//!
//! Features:
//! - Audio fingerprinting (MFCC, spectral features)
//! - SQLite database for sound indexing
//! - Similarity search with segment matching
//! - MIDI export with timestamps

mod frb_generated;

pub mod api;
pub mod fingerprint;
pub mod database;
pub mod search;
pub mod midi;
pub(crate) mod audio;

use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Library error types
#[derive(Error, Debug)]
pub enum AudioPaletteError {
    #[error("Audio loading failed: {0}")]
    AudioLoadError(String),

    #[error("Database error: {0}")]
    DatabaseError(#[from] rusqlite::Error),

    #[error("Fingerprint extraction failed: {0}")]
    FingerprintError(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("MIDI export failed: {0}")]
    MidiError(String),
}

pub type Result<T> = std::result::Result<T, AudioPaletteError>;

/// Audio file metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioMetadata {
    pub filepath: String,
    pub filename: String,
    pub duration: f64,
    pub sample_rate: u32,
    pub channels: u16,
    pub format: String,
}

/// Sound record from database
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SoundRecord {
    pub id: i64,
    pub filepath: String,
    pub filename: String,
    pub duration: f64,
    pub sample_rate: u32,
    pub channels: u16,
    pub format: String,
    pub date_added: String,
}

/// Match result with time range
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MatchResult {
    pub sound_id: i64,
    pub filepath: String,
    pub filename: String,
    pub score: f64,
    pub match_start: f64,
    pub match_end: f64,
    pub file_duration: f64,
}

// FFI exports for Flutter/Dart
#[no_mangle]
pub extern "C" fn audio_palette_version() -> *const std::ffi::c_char {
    static VERSION: &str = concat!(env!("CARGO_PKG_VERSION"), "\0");
    VERSION.as_ptr() as *const std::ffi::c_char
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        let version = audio_palette_version();
        assert!(!version.is_null());
    }
}
