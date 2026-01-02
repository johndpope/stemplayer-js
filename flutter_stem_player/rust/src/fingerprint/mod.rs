//! Audio fingerprinting module
//!
//! Extracts features for similarity matching:
//! - MFCC (Mel-frequency cepstral coefficients)
//! - Spectral centroid, bandwidth, rolloff
//! - Zero-crossing rate
//! - RMS energy
//! - Chroma features

mod mfcc;
mod spectral;

use crate::{AudioPaletteError, Result};
use crate::audio::AudioData;
use rustfft::{FftPlanner, num_complex::Complex};
use serde::{Deserialize, Serialize};

pub use mfcc::MfccExtractor;
pub use spectral::SpectralExtractor;

/// Audio fingerprint containing extracted features
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioFingerprint {
    pub duration: f64,
    pub sample_rate: u32,

    // MFCC features (13 coefficients)
    pub mfcc_mean: Vec<f64>,
    pub mfcc_std: Vec<f64>,

    // Spectral features
    pub spectral_centroid: f64,
    pub spectral_bandwidth: f64,
    pub spectral_rolloff: f64,

    // Energy features
    pub rms_mean: f64,
    pub rms_std: f64,
    pub zero_crossing_rate: f64,

    // Chroma features (12 pitch classes)
    pub chroma_mean: Vec<f64>,
}

impl AudioFingerprint {
    /// Convert fingerprint to a single feature vector for similarity comparison
    pub fn to_vector(&self) -> Vec<f64> {
        let mut vec = Vec::with_capacity(50);

        // MFCC (26 features)
        vec.extend(&self.mfcc_mean);
        vec.extend(&self.mfcc_std);

        // Spectral (3 features, normalized)
        vec.push(self.spectral_centroid / 10000.0);
        vec.push(self.spectral_bandwidth / 10000.0);
        vec.push(self.spectral_rolloff / 10000.0);

        // Energy (3 features)
        vec.push(self.rms_mean);
        vec.push(self.rms_std);
        vec.push(self.zero_crossing_rate);

        // Chroma (12 features)
        vec.extend(&self.chroma_mean);

        vec
    }

    /// Compute cosine similarity between two fingerprints (0-100%)
    pub fn similarity(&self, other: &AudioFingerprint) -> f64 {
        let v1 = self.to_vector();
        let v2 = other.to_vector();

        if v1.len() != v2.len() {
            return 0.0;
        }

        let dot: f64 = v1.iter().zip(v2.iter()).map(|(a, b)| a * b).sum();
        let norm1: f64 = v1.iter().map(|x| x * x).sum::<f64>().sqrt();
        let norm2: f64 = v2.iter().map(|x| x * x).sum::<f64>().sqrt();

        if norm1 == 0.0 || norm2 == 0.0 {
            return 0.0;
        }

        let cosine = dot / (norm1 * norm2);
        // Convert from [-1, 1] to [0, 100]
        ((cosine + 1.0) / 2.0 * 100.0).max(0.0).min(100.0)
    }
}

/// Fingerprint extractor
pub struct Fingerprinter {
    n_mfcc: usize,
    hop_length: usize,
    n_fft: usize,
    mfcc_extractor: MfccExtractor,
    spectral_extractor: SpectralExtractor,
}

impl Default for Fingerprinter {
    fn default() -> Self {
        Self::new(13, 512, 2048)
    }
}

impl Fingerprinter {
    pub fn new(n_mfcc: usize, hop_length: usize, n_fft: usize) -> Self {
        Fingerprinter {
            n_mfcc,
            hop_length,
            n_fft,
            mfcc_extractor: MfccExtractor::new(n_mfcc, n_fft),
            spectral_extractor: SpectralExtractor::new(n_fft, hop_length),
        }
    }

    /// Extract fingerprint from audio file
    pub fn extract_from_file(&self, filepath: &str) -> Result<AudioFingerprint> {
        let audio = AudioData::load(filepath)?;
        self.extract(&audio)
    }

    /// Extract fingerprint from audio samples
    pub fn extract_from_samples(&self, samples: &[f32], sample_rate: u32) -> Result<AudioFingerprint> {
        let audio = AudioData::from_samples(samples.to_vec(), sample_rate);
        self.extract(&audio)
    }

    /// Extract fingerprint from AudioData
    pub fn extract(&self, audio: &AudioData) -> Result<AudioFingerprint> {
        if audio.samples.is_empty() {
            return Err(AudioPaletteError::FingerprintError("Empty audio".to_string()));
        }

        // Extract MFCC features
        let (mfcc_mean, mfcc_std) = self.mfcc_extractor.extract(&audio.samples, audio.sample_rate)?;

        // Extract spectral features
        let spectral = self.spectral_extractor.extract(&audio.samples, audio.sample_rate)?;

        // Extract energy features
        let (rms_mean, rms_std) = self.compute_rms(&audio.samples);
        let zcr = self.compute_zero_crossing_rate(&audio.samples);

        // Extract chroma features
        let chroma_mean = self.compute_chroma(&audio.samples, audio.sample_rate);

        Ok(AudioFingerprint {
            duration: audio.duration,
            sample_rate: audio.sample_rate,
            mfcc_mean,
            mfcc_std,
            spectral_centroid: spectral.centroid,
            spectral_bandwidth: spectral.bandwidth,
            spectral_rolloff: spectral.rolloff,
            rms_mean,
            rms_std,
            zero_crossing_rate: zcr,
            chroma_mean,
        })
    }

    fn compute_rms(&self, samples: &[f32]) -> (f64, f64) {
        let frame_size = self.n_fft;
        let hop = self.hop_length;

        let mut rms_values = Vec::new();

        for start in (0..samples.len()).step_by(hop) {
            let end = (start + frame_size).min(samples.len());
            let frame = &samples[start..end];

            if frame.len() < 64 {
                continue;
            }

            let sum_sq: f64 = frame.iter().map(|&x| (x as f64).powi(2)).sum();
            let rms = (sum_sq / frame.len() as f64).sqrt();
            rms_values.push(rms);
        }

        if rms_values.is_empty() {
            return (0.0, 0.0);
        }

        let mean = rms_values.iter().sum::<f64>() / rms_values.len() as f64;
        let variance = rms_values.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / rms_values.len() as f64;
        let std = variance.sqrt();

        (mean, std)
    }

    fn compute_zero_crossing_rate(&self, samples: &[f32]) -> f64 {
        if samples.len() < 2 {
            return 0.0;
        }

        let mut crossings = 0;
        for i in 1..samples.len() {
            if (samples[i] >= 0.0) != (samples[i - 1] >= 0.0) {
                crossings += 1;
            }
        }

        crossings as f64 / (samples.len() - 1) as f64
    }

    fn compute_chroma(&self, samples: &[f32], sample_rate: u32) -> Vec<f64> {
        // Simplified chroma computation using FFT
        let n_chroma = 12;
        let mut chroma = vec![0.0; n_chroma];

        if samples.len() < self.n_fft {
            return chroma;
        }

        let mut planner = FftPlanner::new();
        let fft = planner.plan_fft_forward(self.n_fft);

        // Process frames
        let mut frame_count = 0;
        for start in (0..samples.len() - self.n_fft).step_by(self.hop_length) {
            let frame: Vec<Complex<f64>> = samples[start..start + self.n_fft]
                .iter()
                .enumerate()
                .map(|(i, &x)| {
                    // Apply Hann window
                    let window = 0.5 * (1.0 - (2.0 * std::f64::consts::PI * i as f64 / (self.n_fft - 1) as f64).cos());
                    Complex::new(x as f64 * window, 0.0)
                })
                .collect();

            let mut buffer = frame;
            fft.process(&mut buffer);

            // Map FFT bins to chroma
            for (i, c) in buffer.iter().enumerate().take(self.n_fft / 2) {
                let freq = i as f64 * sample_rate as f64 / self.n_fft as f64;
                if freq > 0.0 {
                    // Convert frequency to MIDI note, then to chroma
                    let midi = 12.0 * (freq / 440.0).log2() + 69.0;
                    let chroma_bin = ((midi as i32 % 12 + 12) % 12) as usize;
                    let magnitude = c.norm();
                    chroma[chroma_bin] += magnitude;
                }
            }
            frame_count += 1;
        }

        // Normalize
        if frame_count > 0 {
            let max = chroma.iter().cloned().fold(0.0_f64, f64::max);
            if max > 0.0 {
                for c in &mut chroma {
                    *c /= max;
                }
            }
        }

        chroma
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fingerprint_similarity() {
        let fp1 = AudioFingerprint {
            duration: 1.0,
            sample_rate: 44100,
            mfcc_mean: vec![0.0; 13],
            mfcc_std: vec![0.0; 13],
            spectral_centroid: 1000.0,
            spectral_bandwidth: 500.0,
            spectral_rolloff: 2000.0,
            rms_mean: 0.1,
            rms_std: 0.05,
            zero_crossing_rate: 0.1,
            chroma_mean: vec![0.0; 12],
        };

        let similarity = fp1.similarity(&fp1);
        assert!((similarity - 100.0).abs() < 0.01);
    }
}
