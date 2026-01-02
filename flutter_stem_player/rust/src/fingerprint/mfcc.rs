//! MFCC (Mel-Frequency Cepstral Coefficients) extraction

use crate::{AudioPaletteError, Result};
use rustfft::{FftPlanner, num_complex::Complex};

/// MFCC feature extractor
pub struct MfccExtractor {
    n_mfcc: usize,
    n_fft: usize,
    n_mels: usize,
    mel_filterbank: Vec<Vec<f64>>,
}

impl MfccExtractor {
    pub fn new(n_mfcc: usize, n_fft: usize) -> Self {
        let n_mels = 40;
        MfccExtractor {
            n_mfcc,
            n_fft,
            n_mels,
            mel_filterbank: Vec::new(), // Will be computed on first use
        }
    }

    /// Extract MFCC features from audio samples
    /// Returns (mean, std) for each coefficient
    pub fn extract(&self, samples: &[f32], sample_rate: u32) -> Result<(Vec<f64>, Vec<f64>)> {
        if samples.len() < self.n_fft {
            return Err(AudioPaletteError::FingerprintError(
                "Audio too short for MFCC extraction".to_string()
            ));
        }

        // Compute mel filterbank
        let filterbank = self.compute_mel_filterbank(sample_rate);

        let mut planner = FftPlanner::new();
        let fft = planner.plan_fft_forward(self.n_fft);

        let hop_length = self.n_fft / 4;
        let mut all_mfccs: Vec<Vec<f64>> = Vec::new();

        // Process frames
        for start in (0..samples.len().saturating_sub(self.n_fft)).step_by(hop_length) {
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

            // Power spectrum
            let power: Vec<f64> = buffer.iter()
                .take(self.n_fft / 2 + 1)
                .map(|c| c.norm_sqr())
                .collect();

            // Apply mel filterbank
            let mel_spec: Vec<f64> = filterbank.iter()
                .map(|filter| {
                    filter.iter()
                        .zip(power.iter())
                        .map(|(f, p)| f * p)
                        .sum::<f64>()
                        .max(1e-10)
                        .ln()
                })
                .collect();

            // DCT to get MFCCs
            let mfccs = self.dct(&mel_spec);
            all_mfccs.push(mfccs.into_iter().take(self.n_mfcc).collect());
        }

        if all_mfccs.is_empty() {
            return Err(AudioPaletteError::FingerprintError(
                "No frames extracted".to_string()
            ));
        }

        // Compute mean and std for each coefficient
        let n_frames = all_mfccs.len() as f64;
        let mut mean = vec![0.0; self.n_mfcc];
        let mut std = vec![0.0; self.n_mfcc];

        for mfcc in &all_mfccs {
            for (i, &val) in mfcc.iter().enumerate() {
                mean[i] += val;
            }
        }
        for m in &mut mean {
            *m /= n_frames;
        }

        for mfcc in &all_mfccs {
            for (i, &val) in mfcc.iter().enumerate() {
                std[i] += (val - mean[i]).powi(2);
            }
        }
        for s in &mut std {
            *s = (*s / n_frames).sqrt();
        }

        Ok((mean, std))
    }

    fn compute_mel_filterbank(&self, sample_rate: u32) -> Vec<Vec<f64>> {
        let n_bins = self.n_fft / 2 + 1;
        let f_min = 0.0;
        let f_max = sample_rate as f64 / 2.0;

        // Convert to mel scale
        let mel_min = Self::hz_to_mel(f_min);
        let mel_max = Self::hz_to_mel(f_max);

        // Mel points
        let mel_points: Vec<f64> = (0..=self.n_mels + 1)
            .map(|i| mel_min + (mel_max - mel_min) * i as f64 / (self.n_mels + 1) as f64)
            .collect();

        // Convert back to Hz and then to FFT bins
        let hz_points: Vec<f64> = mel_points.iter().map(|&m| Self::mel_to_hz(m)).collect();
        let bin_points: Vec<usize> = hz_points
            .iter()
            .map(|&f| ((f * self.n_fft as f64 / sample_rate as f64) as usize).min(n_bins - 1))
            .collect();

        // Create filterbank
        let mut filterbank = vec![vec![0.0; n_bins]; self.n_mels];

        for i in 0..self.n_mels {
            let start = bin_points[i];
            let center = bin_points[i + 1];
            let end = bin_points[i + 2];

            // Rising slope
            for j in start..center {
                if center > start {
                    filterbank[i][j] = (j - start) as f64 / (center - start) as f64;
                }
            }

            // Falling slope
            for j in center..end {
                if end > center {
                    filterbank[i][j] = (end - j) as f64 / (end - center) as f64;
                }
            }
        }

        filterbank
    }

    fn hz_to_mel(hz: f64) -> f64 {
        2595.0 * (1.0 + hz / 700.0).log10()
    }

    fn mel_to_hz(mel: f64) -> f64 {
        700.0 * (10.0_f64.powf(mel / 2595.0) - 1.0)
    }

    fn dct(&self, x: &[f64]) -> Vec<f64> {
        let n = x.len();
        let mut result = vec![0.0; n];

        for k in 0..n {
            let mut sum = 0.0;
            for (i, &val) in x.iter().enumerate() {
                sum += val * (std::f64::consts::PI * k as f64 * (2.0 * i as f64 + 1.0) / (2.0 * n as f64)).cos();
            }
            result[k] = sum * (2.0 / n as f64).sqrt();
        }

        // Normalize first coefficient
        result[0] *= (0.5_f64).sqrt();

        result
    }
}
