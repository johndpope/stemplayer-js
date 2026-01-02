//! Spectral feature extraction (centroid, bandwidth, rolloff)

use rustfft::{FftPlanner, num_complex::Complex};

/// Spectral features result
#[derive(Debug, Clone)]
pub struct SpectralFeatures {
    pub centroid: f64,
    pub bandwidth: f64,
    pub rolloff: f64,
}

/// Spectral feature extractor
pub struct SpectralExtractor {
    n_fft: usize,
    hop_length: usize,
}

impl SpectralExtractor {
    pub fn new(n_fft: usize, hop_length: usize) -> Self {
        SpectralExtractor { n_fft, hop_length }
    }

    /// Extract spectral features from audio samples
    pub fn extract(&self, samples: &[f32], sample_rate: u32) -> crate::Result<SpectralFeatures> {
        if samples.len() < self.n_fft {
            return Ok(SpectralFeatures {
                centroid: 0.0,
                bandwidth: 0.0,
                rolloff: 0.0,
            });
        }

        let mut planner = FftPlanner::new();
        let fft = planner.plan_fft_forward(self.n_fft);

        let mut centroids = Vec::new();
        let mut bandwidths = Vec::new();
        let mut rolloffs = Vec::new();

        let freq_bins: Vec<f64> = (0..self.n_fft / 2 + 1)
            .map(|i| i as f64 * sample_rate as f64 / self.n_fft as f64)
            .collect();

        for start in (0..samples.len().saturating_sub(self.n_fft)).step_by(self.hop_length) {
            let frame: Vec<Complex<f64>> = samples[start..start + self.n_fft]
                .iter()
                .enumerate()
                .map(|(i, &x)| {
                    let window = 0.5 * (1.0 - (2.0 * std::f64::consts::PI * i as f64 / (self.n_fft - 1) as f64).cos());
                    Complex::new(x as f64 * window, 0.0)
                })
                .collect();

            let mut buffer = frame;
            fft.process(&mut buffer);

            // Magnitude spectrum
            let magnitudes: Vec<f64> = buffer.iter()
                .take(self.n_fft / 2 + 1)
                .map(|c| c.norm())
                .collect();

            let total_energy: f64 = magnitudes.iter().sum();

            if total_energy > 1e-10 {
                // Spectral centroid (weighted mean of frequencies)
                let centroid: f64 = freq_bins.iter()
                    .zip(magnitudes.iter())
                    .map(|(f, m)| f * m)
                    .sum::<f64>() / total_energy;
                centroids.push(centroid);

                // Spectral bandwidth (weighted std of frequencies)
                let bandwidth: f64 = freq_bins.iter()
                    .zip(magnitudes.iter())
                    .map(|(f, m)| (f - centroid).powi(2) * m)
                    .sum::<f64>() / total_energy;
                bandwidths.push(bandwidth.sqrt());

                // Spectral rolloff (frequency below which 85% of energy is contained)
                let threshold = 0.85 * total_energy;
                let mut cumsum = 0.0;
                let mut rolloff = freq_bins.last().copied().unwrap_or(0.0);
                for (i, &mag) in magnitudes.iter().enumerate() {
                    cumsum += mag;
                    if cumsum >= threshold {
                        rolloff = freq_bins[i];
                        break;
                    }
                }
                rolloffs.push(rolloff);
            }
        }

        let mean = |v: &[f64]| -> f64 {
            if v.is_empty() { 0.0 } else { v.iter().sum::<f64>() / v.len() as f64 }
        };

        Ok(SpectralFeatures {
            centroid: mean(&centroids),
            bandwidth: mean(&bandwidths),
            rolloff: mean(&rolloffs),
        })
    }
}
