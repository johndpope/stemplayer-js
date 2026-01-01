import { LitElement, html, css } from 'lit';
import { FFT } from './lib/fft.js';

/**
 * Get color for frequency using continuous gradient (Comparisonics style)
 * Attempt to match Comparisonics reference palette.
 */
function getColorForFrequency(freq) {
  freq = Math.max(50, Math.min(freq, 12000));

  // Color stops matched to Comparisonics reference palette
  const stops = [
    [50, [80, 60, 120]],       // Sub-bass - dark purple
    [100, [90, 70, 130]],
    [200, [100, 80, 140]],     // Bass - purple
    [400, [70, 120, 160]],
    [600, [50, 150, 170]],
    [800, [50, 160, 170]],     // Teal
    [1000, [50, 165, 170]],
    [1200, [55, 170, 165]],
    [1300, [70, 165, 150]],
    [1400, [130, 160, 110]],
    [1500, [200, 195, 85]],    // Yellow emerging
    [1580, [220, 200, 80]],    // Yellow
    [1800, [235, 195, 75]],
    [2000, [250, 180, 90]],
    [2400, [250, 170, 100]],   // Orange
    [2800, [250, 150, 120]],
    [3200, [248, 135, 150]],
    [3800, [245, 120, 170]],   // Pink
    [4500, [240, 100, 185]],
    [5500, [230, 85, 195]],
    [7000, [220, 80, 200]],    // Magenta
    [10000, [200, 60, 220]],
  ];

  for (let i = 0; i < stops.length - 1; i++) {
    if (freq <= stops[i + 1][0]) {
      const [f1, c1] = stops[i];
      const [f2, c2] = stops[i + 1];
      const t = (freq - f1) / (f2 - f1);
      return [
        Math.round(c1[0] + (c2[0] - c1[0]) * t),
        Math.round(c1[1] + (c2[1] - c1[1]) * t),
        Math.round(c1[2] + (c2[2] - c1[2]) * t),
      ];
    }
  }
  return stops[stops.length - 1][1];
}

/**
 * A waveform component that displays Comparisonics-style frequency coloring.
 * @element fc-frequency-waveform
 */
export class FcFrequencyWaveform extends LitElement {
  static get styles() {
    return css`
      :host {
        display: block;
        width: 100%;
        height: 100%;
        position: relative;
        cursor: pointer;
        box-sizing: border-box;
      }
      .container {
        position: relative;
        width: 100%;
        height: 100%;
        background: #f8f8f8;
      }
      canvas {
        display: block;
        width: 100%;
        height: 100%;
      }
      .loading-indicator {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        font-size: 11px;
        color: #666;
        opacity: 0.7;
      }
      .loading-indicator .spinner {
        display: inline-block;
        width: 12px;
        height: 12px;
        border: 2px solid currentColor;
        border-top-color: transparent;
        border-radius: 50%;
        animation: spin 0.8s linear infinite;
        margin-right: 6px;
        vertical-align: middle;
      }
      @keyframes spin {
        to { transform: rotate(360deg); }
      }
    `;
  }

  static get properties() {
    return {
      src: { type: String },
      audioSrc: { type: String, attribute: 'audio-src' },
      peaks: { type: Object },
      progress: { type: Number },
      scaleY: { type: Number },
      pixelRatio: { type: Number },
      audioBuffer: { type: Object },
      loading: { type: Boolean, state: true },
    };
  }

  #canvas;
  #ctx;
  #resizeObserver;
  #audioData = null;
  #sampleRate = 44100;
  #audioContext = null;
  #frequencyData = [];
  #peaksData = null;
  #audioDuration = 0;

  constructor() {
    super();
    this.progress = 0;
    this.scaleY = 1;
    this.pixelRatio = window.devicePixelRatio || 2;
    this.loading = false;
  }

  connectedCallback() {
    super.connectedCallback();
    this.#resizeObserver = new ResizeObserver(() => this.#draw());
  }

  disconnectedCallback() {
    super.disconnectedCallback();
    this.#resizeObserver?.disconnect();
  }

  firstUpdated() {
    this.#canvas = this.shadowRoot.querySelector('canvas');
    this.#ctx = this.#canvas.getContext('2d');
    this.#resizeObserver.observe(this);

    if (this.src) {
      this.#loadWaveformData();
    } else if (this.audioSrc) {
      this.#loadAudioFromSrc();
    } else if (this.audioBuffer) {
      this.#processAudioBuffer();
    }

    this.#canvas.addEventListener('click', e => {
      const rect = this.#canvas.getBoundingClientRect();
      const pct = (e.clientX - rect.left) / rect.width;
      this.dispatchEvent(new CustomEvent('waveform:seek', {
        detail: pct,
        bubbles: true,
        composed: true,
      }));
    });

    requestAnimationFrame(() => this.#draw());
  }

  updated(changedProperties) {
    if (changedProperties.has('src') && this.src) {
      this.#loadWaveformData();
    }
    if (changedProperties.has('audioSrc') && this.audioSrc) {
      this.#loadAudioFromSrc();
    }
    if (changedProperties.has('audioBuffer') && this.audioBuffer) {
      this.#processAudioBuffer();
    }
    if (changedProperties.has('progress') || changedProperties.has('scaleY')) {
      this.#draw();
    }
  }

  async #loadAudioFromSrc() {
    if (!this.audioSrc || this.loading) return;
    this.loading = true;
    try {
      if (!this.#audioContext) {
        this.#audioContext = new (window.AudioContext || window.webkitAudioContext)();
      }
      const response = await fetch(this.audioSrc);
      const arrayBuffer = await response.arrayBuffer();
      const audioBuffer = await this.#audioContext.decodeAudioData(arrayBuffer);
      this.#sampleRate = audioBuffer.sampleRate;
      this.#audioDuration = audioBuffer.duration;
      this.#extractAudioData(audioBuffer);
      this.#analyzeAllFrequencies();
      this.#draw();
    } catch (err) {
      console.error('Error loading audio:', err);
    } finally {
      this.loading = false;
    }
  }

  async #loadWaveformData() {
    try {
      const response = await fetch(this.src);
      const data = await response.json();
      this.#peaksData = Array.isArray(data) ? data : data.data || data.peaks || [];
      this.#draw();
    } catch (err) {
      console.error('Error loading waveform data:', err);
    }
  }

  #processAudioBuffer() {
    if (!this.audioBuffer) return;
    this.#sampleRate = this.audioBuffer.sampleRate;
    this.#audioDuration = this.audioBuffer.duration;
    this.#extractAudioData(this.audioBuffer);
    this.#analyzeAllFrequencies();
    this.#draw();
  }

  #extractAudioData(audioBuffer) {
    let signal = audioBuffer.getChannelData(0);
    if (audioBuffer.numberOfChannels > 1) {
      const ch2 = audioBuffer.getChannelData(1);
      const mixed = new Float32Array(signal.length);
      for (let i = 0; i < signal.length; i++) {
        mixed[i] = (signal[i] + ch2[i]) / 2;
      }
      signal = mixed;
    }
    this.#audioData = signal;

    const minSamplesPerPeak = 32;
    const numPeaks = Math.max(1, Math.floor(signal.length / minSamplesPerPeak));
    const samplesPerPeak = signal.length / numPeaks;
    const peaks = [];
    for (let i = 0; i < numPeaks; i++) {
      const start = Math.floor(i * samplesPerPeak);
      const end = Math.floor(start + samplesPerPeak);
      let min = 1, max = -1;
      for (let j = start; j < end && j < signal.length; j++) {
        if (signal[j] < min) min = signal[j];
        if (signal[j] > max) max = signal[j];
      }
      peaks.push(min, max);
    }
    this.#peaksData = peaks;
  }

  #analyzeAllFrequencies() {
    if (!this.#audioData) return;

    const signal = this.#audioData;
    const sampleRate = this.#sampleRate;

    // Dynamic segment count based on audio length
    const minSamplesPerSegment = 256;
    let numSegments = Math.max(1, Math.floor(signal.length / minSamplesPerSegment));
    // Cap segments to avoid excessive computation
    numSegments = Math.min(numSegments, 2000);
    const samplesPerSegment = Math.floor(signal.length / numSegments);

    let fftSize = 2048;
    while (fftSize > samplesPerSegment && fftSize > 128) {
      fftSize /= 2;
    }

    this.#frequencyData = [];

    const LOW_MAX = 1100;
    const HIGH_MIN = 2000;
    const ENERGY_THRESHOLD = 1e-6;

    for (let seg = 0; seg < numSegments; seg++) {
      const start = seg * samplesPerSegment;
      if (start >= signal.length) break;

      const buffer = new Float64Array(fftSize);
      let segMin = 1, segMax = -1;
      for (let j = 0; j < fftSize; j++) {
        const idx = start + j;
        if (idx >= signal.length) break;
        const val = signal[idx];
        if (val < segMin) segMin = val;
        if (val > segMax) segMax = val;
        const window = 0.5 * (1 - Math.cos((2 * Math.PI * j) / (fftSize - 1)));
        buffer[j] = val * window;
      }

      const fft = new FFT(fftSize, sampleRate);
      const spectrum = fft.forward(buffer);

      let lowEnergy = 0, midEnergy = 0, highEnergy = 0;
      let totalEnergy = 0;

      // FFT returns array of magnitudes (not interleaved complex)
      const numBins = spectrum.length;
      for (let bin = 1; bin < numBins; bin++) {
        const mag = spectrum[bin];
        const power = mag * mag;
        const freq = (bin * sampleRate) / fftSize;
        totalEnergy += power;

        if (freq < LOW_MAX) {
          lowEnergy += power;
        } else if (freq < HIGH_MIN) {
          midEnergy += power;
        } else {
          highEnergy += power;
        }
      }

      if (totalEnergy < ENERGY_THRESHOLD) {
        this.#frequencyData.push({
          min: 0,
          max: 0,
          centroid: 500,
          lowEnergy: 0,
          midEnergy: 0,
          highEnergy: 0,
        });
        continue;
      }

      lowEnergy /= totalEnergy;
      midEnergy /= totalEnergy;
      highEnergy /= totalEnergy;

      let weightedFreq = 0, totalMag = 0;
      for (let bin = 1; bin < numBins; bin++) {
        const mag = spectrum[bin];
        const freq = (bin * sampleRate) / fftSize;
        totalMag += mag;
        weightedFreq += freq * mag;
      }
      const centroid = totalMag > 0 ? weightedFreq / totalMag : 500;

      this.#frequencyData.push({
        min: segMin,
        max: segMax,
        centroid,
        lowEnergy,
        midEnergy,
        highEnergy,
      });
    }
  }

  #draw() {
    if (!this.#canvas || !this.#ctx) return;

    const canvas = this.#canvas;
    const ctx = this.#ctx;
    const pixelRatio = this.pixelRatio || 2;

    let width = this.offsetWidth || this.clientWidth || 800;
    let height = this.offsetHeight || this.clientHeight || 60;

    if (width === 0) width = this.parentElement?.offsetWidth || 800;
    if (height === 0) height = this.parentElement?.offsetHeight || 60;

    canvas.width = width * pixelRatio;
    canvas.height = height * pixelRatio;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.scale(pixelRatio, pixelRatio);

    ctx.fillStyle = '#f8f8f8';
    ctx.fillRect(0, 0, width, height);

    const mid = height / 2;
    ctx.strokeStyle = '#ddd';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, mid);
    ctx.lineTo(width, mid);
    ctx.stroke();

    if (this.#frequencyData.length > 0) {
      this.#drawMultiBandWaveform(ctx, width, height);
    } else if (this.#peaksData && this.#peaksData.length > 0) {
      this.#drawSimpleWaveform(ctx, width, height);
    }

    if (this.progress > 0) {
      const progressX = this.progress * width;
      ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
      ctx.fillRect(progressX, 0, width - progressX, height);
    }
  }

  #drawMultiBandWaveform(ctx, width, height) {
    const mid = height / 2;
    const scaleY = this.scaleY || 1;
    const numSegments = this.#frequencyData.length;

    // Calculate the proportion of width to use based on audio duration
    // Assuming a "reference" duration (e.g., 10 seconds fills the width)
    const referenceDuration = 10; // seconds
    const durationRatio = Math.min(1, this.#audioDuration / referenceDuration);
    const usedWidth = width * durationRatio;

    const segmentWidth = usedWidth / numSegments;
    const AMPLITUDE_THRESHOLD = 0.01;

    for (let i = 0; i < numSegments; i++) {
      const seg = this.#frequencyData[i];
      const x = i * segmentWidth;

      const amplitude = Math.max(Math.abs(seg.min), Math.abs(seg.max)) * scaleY;
      if (amplitude < AMPLITUDE_THRESHOLD) continue;

      const totalHeight = amplitude * mid * 0.95;
      if (totalHeight < 0.5) continue;

      if (seg.highEnergy > 0.08) {
        const pink = [240, 115, 185];
        ctx.fillStyle = `rgb(${pink[0]}, ${pink[1]}, ${pink[2]})`;
        ctx.fillRect(x, mid - totalHeight, segmentWidth + 0.3, totalHeight * 2);

        const innerRatio = Math.max(0.25, 0.55 - seg.highEnergy);
        const innerHeight = totalHeight * innerRatio;
        const innerColor = getColorForFrequency(seg.centroid);
        ctx.fillStyle = `rgb(${innerColor[0]}, ${innerColor[1]}, ${innerColor[2]})`;
        ctx.fillRect(x, mid - innerHeight, segmentWidth + 0.3, innerHeight * 2);
      } else {
        const color = getColorForFrequency(seg.centroid);
        ctx.fillStyle = `rgb(${color[0]}, ${color[1]}, ${color[2]})`;
        ctx.fillRect(x, mid - totalHeight, segmentWidth + 0.3, totalHeight * 2);
      }
    }
  }

  #drawSimpleWaveform(ctx, width, height) {
    const peaks = this.#peaksData;
    const mid = height / 2;
    const scaleY = this.scaleY || 1;
    const numBars = peaks.length / 2;
    const barWidth = width / numBars;

    for (let i = 0; i < numBars; i++) {
      const x = i * barWidth;
      const peakIdx = i * 2;
      const min = peaks[peakIdx] * scaleY;
      const max = peaks[peakIdx + 1] * scaleY;

      const barHeight = ((max - min) / 2) * mid;
      const y = mid - max * mid;

      ctx.fillStyle = 'rgba(80, 180, 160, 0.7)';
      ctx.fillRect(x, y, barWidth - 0.5, barHeight * 2);
    }
  }

  get adjustedPeaks() {
    if (!this.#peaksData) return null;
    const scaleY = this.scaleY || 1;
    const data = this.#peaksData.map(p => p * scaleY);
    return { data, sample_rate: this.#sampleRate, length: data.length };
  }

  render() {
    return html`
      <div class="container">
        <canvas></canvas>
        ${this.loading ? html`
          <div class="loading-indicator">
            <span class="spinner"></span>Loading...
          </div>
        ` : ''}
      </div>
    `;
  }
}

if (!customElements.get('fc-frequency-waveform')) {
  customElements.define('fc-frequency-waveform', FcFrequencyWaveform);
}
