//! Audio loading and decoding module
//!
//! Supports: WAV, MP3, FLAC, OGG, AAC via Symphonia

use crate::{AudioMetadata, AudioPaletteError, Result};
use std::fs::File;
use std::path::Path;
use symphonia::core::audio::SampleBuffer;
use symphonia::core::codecs::DecoderOptions;
use symphonia::core::formats::FormatOptions;
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;

/// Loaded audio data
#[derive(Debug, Clone)]
pub struct AudioData {
    pub samples: Vec<f32>,
    pub sample_rate: u32,
    pub channels: u16,
    pub duration: f64,
}

impl AudioData {
    /// Load audio from file path
    pub fn load<P: AsRef<Path>>(path: P) -> Result<Self> {
        let path = path.as_ref();
        let file = File::open(path)
            .map_err(|e| AudioPaletteError::AudioLoadError(format!("Cannot open file: {}", e)))?;

        let mss = MediaSourceStream::new(Box::new(file), Default::default());

        // Probe the format
        let mut hint = Hint::new();
        if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
            hint.with_extension(ext);
        }

        let probed = symphonia::default::get_probe()
            .format(&hint, mss, &FormatOptions::default(), &MetadataOptions::default())
            .map_err(|e| AudioPaletteError::AudioLoadError(format!("Format probe failed: {}", e)))?;

        let mut format = probed.format;

        // Get the default track
        let track = format
            .default_track()
            .ok_or_else(|| AudioPaletteError::AudioLoadError("No audio track found".to_string()))?;

        let sample_rate = track.codec_params.sample_rate.unwrap_or(44100);
        let channels = track.codec_params.channels.map(|c| c.count() as u16).unwrap_or(2);

        // Create decoder
        let mut decoder = symphonia::default::get_codecs()
            .make(&track.codec_params, &DecoderOptions::default())
            .map_err(|e| AudioPaletteError::AudioLoadError(format!("Decoder creation failed: {}", e)))?;

        let track_id = track.id;
        let mut samples: Vec<f32> = Vec::new();

        // Decode all packets
        loop {
            let packet = match format.next_packet() {
                Ok(packet) => packet,
                Err(symphonia::core::errors::Error::IoError(e))
                    if e.kind() == std::io::ErrorKind::UnexpectedEof =>
                {
                    break;
                }
                Err(e) => {
                    // Log but continue - some packets may fail
                    log::warn!("Packet decode error: {}", e);
                    continue;
                }
            };

            if packet.track_id() != track_id {
                continue;
            }

            match decoder.decode(&packet) {
                Ok(decoded) => {
                    let spec = *decoded.spec();
                    let duration = decoded.capacity() as u64;

                    let mut sample_buf = SampleBuffer::<f32>::new(duration, spec);
                    sample_buf.copy_interleaved_ref(decoded);

                    // Convert to mono by averaging channels
                    let interleaved = sample_buf.samples();
                    let ch = spec.channels.count();

                    for chunk in interleaved.chunks(ch) {
                        let mono: f32 = chunk.iter().sum::<f32>() / ch as f32;
                        samples.push(mono);
                    }
                }
                Err(e) => {
                    log::warn!("Decode error: {}", e);
                    continue;
                }
            }
        }

        let duration = samples.len() as f64 / sample_rate as f64;

        Ok(AudioData {
            samples,
            sample_rate,
            channels,
            duration,
        })
    }

    /// Load audio from raw samples (for processing selections)
    pub fn from_samples(samples: Vec<f32>, sample_rate: u32) -> Self {
        let duration = samples.len() as f64 / sample_rate as f64;
        AudioData {
            samples,
            sample_rate,
            channels: 1,
            duration,
        }
    }

    /// Get a range of samples
    pub fn get_range(&self, start_sample: usize, end_sample: usize) -> Vec<f32> {
        let start = start_sample.min(self.samples.len());
        let end = end_sample.min(self.samples.len());
        self.samples[start..end].to_vec()
    }

    /// Get metadata for this audio
    pub fn metadata(&self, filepath: &str) -> AudioMetadata {
        let path = Path::new(filepath);
        let filename = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string();

        let format = path
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("unknown")
            .to_lowercase();

        AudioMetadata {
            filepath: filepath.to_string(),
            filename,
            duration: self.duration,
            sample_rate: self.sample_rate,
            channels: self.channels,
            format,
        }
    }
}

/// Get audio metadata without fully decoding
pub fn get_metadata<P: AsRef<Path>>(path: P) -> Result<AudioMetadata> {
    let path = path.as_ref();
    let file = File::open(path)
        .map_err(|e| AudioPaletteError::AudioLoadError(format!("Cannot open file: {}", e)))?;

    let mss = MediaSourceStream::new(Box::new(file), Default::default());

    let mut hint = Hint::new();
    if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
        hint.with_extension(ext);
    }

    let probed = symphonia::default::get_probe()
        .format(&hint, mss, &FormatOptions::default(), &MetadataOptions::default())
        .map_err(|e| AudioPaletteError::AudioLoadError(format!("Format probe failed: {}", e)))?;

    let track = probed
        .format
        .default_track()
        .ok_or_else(|| AudioPaletteError::AudioLoadError("No audio track found".to_string()))?;

    let sample_rate = track.codec_params.sample_rate.unwrap_or(44100);
    let channels = track.codec_params.channels.map(|c| c.count() as u16).unwrap_or(2);

    let n_frames = track.codec_params.n_frames.unwrap_or(0);
    let duration = n_frames as f64 / sample_rate as f64;

    let filename = path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unknown")
        .to_string();

    let format = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("unknown")
        .to_lowercase();

    Ok(AudioMetadata {
        filepath: path.to_string_lossy().to_string(),
        filename,
        duration,
        sample_rate,
        channels,
        format,
    })
}
