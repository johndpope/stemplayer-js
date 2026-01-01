/**
 * FFT (Fast Fourier Transform) implementation for frequency analysis
 * Based on the Cooley-Tukey algorithm
 */

/**
 * Base Fourier Transform class
 */
export class FourierTransform {
  constructor(bufferSize, sampleRate) {
    this.bufferSize = bufferSize;
    this.sampleRate = sampleRate;
    this.bandwidth = (2 / bufferSize) * (sampleRate / 2);
    this.spectrum = new Float64Array(bufferSize / 2);
    this.real = new Float64Array(bufferSize);
    this.imag = new Float64Array(bufferSize);
    this.peakBand = 0;
    this.peak = 0;
  }
}

/**
 * FFT implementation using Cooley-Tukey algorithm
 */
export class FFT extends FourierTransform {
  constructor(bufferSize, sampleRate) {
    super(bufferSize, sampleRate);

    this.reverseTable = new Uint32Array(bufferSize);

    let limit = 1;
    let bit = bufferSize >> 1;

    while (limit < bufferSize) {
      for (let i = 0; i < limit; i++) {
        this.reverseTable[i + limit] = this.reverseTable[i] + bit;
      }
      limit = limit << 1;
      bit = bit >> 1;
    }

    this.sinTable = new Float64Array(bufferSize);
    this.cosTable = new Float64Array(bufferSize);

    for (let i = 0; i < bufferSize; i++) {
      this.sinTable[i] = Math.sin(-Math.PI / i);
      this.cosTable[i] = Math.cos(-Math.PI / i);
    }
  }

  /**
   * Perform forward FFT on the buffer
   * @param {Float32Array|Float64Array} buffer - Input signal buffer
   * @returns {Float64Array} Spectrum data
   */
  forward(buffer) {
    const { bufferSize, cosTable, sinTable, reverseTable, real, imag } = this;

    const k = Math.floor(Math.log(bufferSize) / Math.LN2);
    if (Math.pow(2, k) !== bufferSize) {
      throw new Error('Invalid buffer size, must be a power of 2.');
    }
    if (bufferSize !== buffer.length) {
      throw new Error('Supplied buffer is not the same size as defined FFT.');
    }

    // Bit-reversal permutation
    for (let i = 0; i < bufferSize; i++) {
      real[i] = buffer[reverseTable[i]];
      imag[i] = 0;
    }

    // Cooley-Tukey decimation-in-time
    let halfSize = 1;
    while (halfSize < bufferSize) {
      const phaseShiftStepReal = cosTable[halfSize];
      const phaseShiftStepImag = sinTable[halfSize];

      let currentPhaseShiftReal = 1;
      let currentPhaseShiftImag = 0;

      for (let fftStep = 0; fftStep < halfSize; fftStep++) {
        let i = fftStep;

        while (i < bufferSize) {
          const off = i + halfSize;
          const tr =
            currentPhaseShiftReal * real[off] -
            currentPhaseShiftImag * imag[off];
          const ti =
            currentPhaseShiftReal * imag[off] +
            currentPhaseShiftImag * real[off];

          real[off] = real[i] - tr;
          imag[off] = imag[i] - ti;
          real[i] += tr;
          imag[i] += ti;

          i += halfSize << 1;
        }

        const tmpReal = currentPhaseShiftReal;
        currentPhaseShiftReal =
          tmpReal * phaseShiftStepReal -
          currentPhaseShiftImag * phaseShiftStepImag;
        currentPhaseShiftImag =
          tmpReal * phaseShiftStepImag +
          currentPhaseShiftImag * phaseShiftStepReal;
      }

      halfSize = halfSize << 1;
    }

    return this.calculateSpectrum();
  }

  /**
   * Calculate magnitude spectrum from real/imag components
   * @returns {Float64Array} Spectrum magnitudes
   */
  calculateSpectrum() {
    const { spectrum, real, imag, bufferSize } = this;
    const bSi = 2 / bufferSize;

    for (let i = 0, N = bufferSize / 2; i < N; i++) {
      const rval = real[i];
      const ival = imag[i];
      const mag = bSi * Math.sqrt(rval * rval + ival * ival);

      if (mag > this.peak) {
        this.peakBand = i;
        this.peak = mag;
      }

      spectrum[i] = mag;
    }

    return spectrum;
  }
}

/**
 * Default frequency bands aligned to Comparisonics color scheme
 * More granular mapping with purple→teal→green→yellow→orange→pink→magenta
 * Inspired by U.S. Patent 6,184,898
 */
export const DEFAULT_FREQUENCY_BANDS = [
  // Bass range (purple/violet)
  { min: 0, max: 80, color: '#2a1060' }, // Sub-bass: very dark purple
  { min: 80, max: 150, color: '#3a1870' }, // Sub-bass: dark purple
  { min: 150, max: 250, color: '#4a2080' }, // Bass: purple
  { min: 250, max: 350, color: '#5030a0' }, // Bass: blue-purple
  // Low range (teal/cyan)
  { min: 350, max: 450, color: '#206080' }, // Low: dark teal
  { min: 450, max: 550, color: '#108080' }, // Low: teal
  { min: 550, max: 700, color: '#20a090' }, // Low-mid: teal-green
  // Mid range (green)
  { min: 700, max: 900, color: '#30b060' }, // Mid-low: green
  { min: 900, max: 1100, color: '#50c040' }, // Mid: bright green
  { min: 1100, max: 1400, color: '#80d030' }, // Mid: yellow-green
  // Upper-mid range (yellow/gold)
  { min: 1400, max: 1700, color: '#b0c020' }, // Mid-high: yellow-green
  { min: 1700, max: 2000, color: '#d0b020' }, // Upper-mid: gold
  { min: 2000, max: 2400, color: '#e0a030' }, // Upper-mid: orange-gold
  // Presence range (orange/salmon)
  { min: 2400, max: 2900, color: '#e08040' }, // Presence: orange
  { min: 2900, max: 3500, color: '#e06050' }, // Presence: salmon-orange
  // High range (pink/magenta)
  { min: 3500, max: 4200, color: '#e05080' }, // High: salmon-pink
  { min: 4200, max: 5000, color: '#d04090' }, // High: pink
  { min: 5000, max: 6500, color: '#c030a0' }, // Very high: magenta-pink
  { min: 6500, max: 9000, color: '#a020b0' }, // Very high: magenta
  { min: 9000, max: Infinity, color: '#8010c0' }, // Ultra high: purple-magenta
];

/**
 * Get color for a given frequency based on frequency bands
 * @param {number} frequency - Frequency in Hz
 * @param {Array} bands - Array of frequency band objects
 * @returns {string} CSS color string
 */
export function getColorForFrequency(frequency, bands = DEFAULT_FREQUENCY_BANDS) {
  for (const band of bands) {
    if (frequency >= band.min && frequency < band.max) {
      return band.color;
    }
  }
  return '#808080'; // Default gray for out-of-range frequencies
}

/**
 * Analyze audio buffer and compute per-segment frequency colors
 * @param {Float32Array} signal - Audio signal data
 * @param {number} sampleRate - Sample rate in Hz
 * @param {number} numSegments - Number of segments to analyze
 * @param {Array} bands - Frequency band definitions
 * @returns {Array} Array of color strings for each segment
 */
export function analyzeFrequencyColors(
  signal,
  sampleRate,
  numSegments,
  bands = DEFAULT_FREQUENCY_BANDS,
) {
  // Calculate FFT size based on segment duration (~0.05 seconds for better resolution)
  const segmentDuration = 0.05;
  let fftSize = Math.pow(
    2,
    Math.ceil(Math.log2(sampleRate * segmentDuration)),
  );

  // Ensure minimum FFT size
  fftSize = Math.max(fftSize, 256);
  // Ensure maximum FFT size for performance
  fftSize = Math.min(fftSize, 4096);

  const samplesPerSegment = Math.floor(signal.length / numSegments);
  const colors = new Array(numSegments);

  for (let seg = 0; seg < numSegments; seg++) {
    const start = seg * samplesPerSegment;

    // Create buffer for FFT (use actual segment size or FFT size, whichever is smaller)
    const actualFftSize = Math.min(fftSize, samplesPerSegment);
    const paddedFftSize = Math.pow(2, Math.ceil(Math.log2(actualFftSize)));

    const buffer = new Float64Array(paddedFftSize);
    for (let j = 0; j < paddedFftSize; j++) {
      buffer[j] = signal[start + j] || 0;
    }

    const fft = new FFT(paddedFftSize, sampleRate);
    const spectrum = fft.forward(buffer);

    // Find dominant frequency bin
    let maxMag = 0;
    let maxBin = 0;
    for (let j = 1; j < spectrum.length; j++) {
      if (spectrum[j] > maxMag) {
        maxMag = spectrum[j];
        maxBin = j;
      }
    }

    const dominantFreq = (maxBin * sampleRate) / paddedFftSize;

    // Assign color based on dominant frequency
    colors[seg] = getColorForFrequency(dominantFreq, bands);
  }

  return colors;
}

export default { FFT, FourierTransform, analyzeFrequencyColors, getColorForFrequency, DEFAULT_FREQUENCY_BANDS };
