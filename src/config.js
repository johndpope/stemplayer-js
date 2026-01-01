export const fetchOptions = {};

export const responsiveBreakpoints = {
  xs: '600',
  sm: '800',
};

export const waveform = {
  waveColor: '#AAA',
  progressColor: 'rgb(0, 206, 224)',
  devicePixelRatio: 2,
  barGap: 2,
  barWidth: 2,
};

/**
 * Frequency-based waveform coloring configuration
 * Inspired by U.S. Patent 6,184,898 (Comparisonics color scheme)
 * Dark colors for bass, blues/greens for mid, reds/oranges for high
 */
export const frequencyWaveform = {
  enabled: false, // Set to true to enable by default
  progressOverlayColor: 'rgba(0, 206, 224, 0.6)',
  devicePixelRatio: 2,
  barGap: 1,
  barWidth: 2,
  // Frequency bands (Hz) with associated colors
  bands: [
    { min: 0, max: 100, color: '#1a0a2e' }, // Sub-bass: very dark purple
    { min: 100, max: 300, color: '#16213e' }, // Bass: dark blue
    { min: 300, max: 1000, color: '#0f4c75' }, // Low-mid: blue
    { min: 1000, max: 3000, color: '#3282b8' }, // Mid: lighter blue
    { min: 3000, max: 6000, color: '#2e8b57' }, // Upper-mid: green
    { min: 6000, max: 10000, color: '#ffc107' }, // Presence: yellow
    { min: 10000, max: 15000, color: '#ff6b35' }, // Brilliance: orange
    { min: 15000, max: Infinity, color: '#d62828' }, // Air: red
  ],
};

export const defaults = {
  waveform,
  frequencyWaveform,
};

export default { fetchOptions, responsiveBreakpoints, defaults };
