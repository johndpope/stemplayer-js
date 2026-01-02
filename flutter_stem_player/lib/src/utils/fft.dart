import 'dart:math' as math;
import 'dart:typed_data';

/// FFT (Fast Fourier Transform) implementation - Cooley-Tukey algorithm
/// Ported from stemplayer-js
class FFT {
  final int bufferSize;
  final double sampleRate;
  late final Float64List spectrum;
  late final Float64List real;
  late final Float64List imag;
  late final Uint32List reverseTable;
  late final Float64List sinTable;
  late final Float64List cosTable;
  double peak = 0;
  int peakBand = 0;

  FFT(this.bufferSize, this.sampleRate) {
    spectrum = Float64List(bufferSize ~/ 2);
    real = Float64List(bufferSize);
    imag = Float64List(bufferSize);
    reverseTable = Uint32List(bufferSize);
    sinTable = Float64List(bufferSize);
    cosTable = Float64List(bufferSize);

    // Build reverse table
    int limit = 1;
    int bit = bufferSize >> 1;
    while (limit < bufferSize) {
      for (int i = 0; i < limit; i++) {
        reverseTable[i + limit] = reverseTable[i] + bit;
      }
      limit = limit << 1;
      bit = bit >> 1;
    }

    // Build trig tables
    for (int i = 0; i < bufferSize; i++) {
      sinTable[i] = math.sin(-math.pi / i);
      cosTable[i] = math.cos(-math.pi / i);
    }
  }

  /// Perform forward FFT on the buffer
  Float64List forward(Float64List buffer) {
    if (buffer.length != bufferSize) {
      throw ArgumentError('Buffer length must equal FFT size');
    }

    // Bit-reversal permutation
    for (int i = 0; i < bufferSize; i++) {
      real[i] = buffer[reverseTable[i]];
      imag[i] = 0;
    }

    // Cooley-Tukey decimation-in-time
    int halfSize = 1;
    while (halfSize < bufferSize) {
      final phaseShiftStepReal = cosTable[halfSize];
      final phaseShiftStepImag = sinTable[halfSize];

      double currentPhaseShiftReal = 1;
      double currentPhaseShiftImag = 0;

      for (int fftStep = 0; fftStep < halfSize; fftStep++) {
        int i = fftStep;

        while (i < bufferSize) {
          final off = i + halfSize;
          final tr = currentPhaseShiftReal * real[off] -
              currentPhaseShiftImag * imag[off];
          final ti = currentPhaseShiftReal * imag[off] +
              currentPhaseShiftImag * real[off];

          real[off] = real[i] - tr;
          imag[off] = imag[i] - ti;
          real[i] += tr;
          imag[i] += ti;

          i += halfSize << 1;
        }

        final tmpReal = currentPhaseShiftReal;
        currentPhaseShiftReal =
            tmpReal * phaseShiftStepReal - currentPhaseShiftImag * phaseShiftStepImag;
        currentPhaseShiftImag =
            tmpReal * phaseShiftStepImag + currentPhaseShiftImag * phaseShiftStepReal;
      }

      halfSize = halfSize << 1;
    }

    return _calculateSpectrum();
  }

  Float64List _calculateSpectrum() {
    final bSi = 2 / bufferSize;
    peak = 0;
    peakBand = 0;

    for (int i = 0; i < bufferSize ~/ 2; i++) {
      final rval = real[i];
      final ival = imag[i];
      final mag = bSi * math.sqrt(rval * rval + ival * ival);

      if (mag > peak) {
        peakBand = i;
        peak = mag;
      }

      spectrum[i] = mag;
    }

    return spectrum;
  }
}

/// Color stops for Comparisonics-style frequency coloring
/// Matches the JavaScript implementation exactly
List<int> getColorForFrequency(double freq) {
  freq = freq.clamp(50, 12000);

  // Color stops matched to Comparisonics reference palette
  const stops = <List<dynamic>>[
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

  for (int i = 0; i < stops.length - 1; i++) {
    if (freq <= (stops[i + 1][0] as num).toDouble()) {
      final f1 = (stops[i][0] as num).toDouble();
      final c1 = stops[i][1] as List<int>;
      final f2 = (stops[i + 1][0] as num).toDouble();
      final c2 = stops[i + 1][1] as List<int>;
      final t = (freq - f1) / (f2 - f1);
      return [
        (c1[0] + (c2[0] - c1[0]) * t).round(),
        (c1[1] + (c2[1] - c1[1]) * t).round(),
        (c1[2] + (c2[2] - c1[2]) * t).round(),
      ];
    }
  }
  return (stops.last[1] as List<int>);
}

/// Frequency segment data from FFT analysis
class FrequencySegment {
  final double min;
  final double max;
  final double centroid;
  final double lowEnergy;
  final double midEnergy;
  final double highEnergy;
  final int colorInt;

  FrequencySegment({
    required this.min,
    required this.max,
    required this.centroid,
    required this.lowEnergy,
    required this.midEnergy,
    required this.highEnergy,
  }) : colorInt = _colorToInt(getColorForFrequency(centroid));

  static int _colorToInt(List<int> rgb) {
    return 0xFF000000 | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2];
  }
}

/// Frequency bands helper (for legend)
class FrequencyBands {
  static const List<FrequencyBandInfo> bands = [
    FrequencyBandInfo('Bass', 50, 200, 0xFF64508C),
    FrequencyBandInfo('Low', 200, 800, 0xFF3C8CA0),
    FrequencyBandInfo('Mid', 800, 1500, 0xFF64C864),
    FrequencyBandInfo('Upper', 1500, 2500, 0xFFF0DC64),
    FrequencyBandInfo('Presence', 2500, 4000, 0xFFFA9696),
    FrequencyBandInfo('High', 4000, 7000, 0xFFE664B4),
    FrequencyBandInfo('V.High', 7000, 20000, 0xFFC850C8),
  ];
}

class FrequencyBandInfo {
  final String name;
  final double minFreq;
  final double maxFreq;
  final int color;

  const FrequencyBandInfo(this.name, this.minFreq, this.maxFreq, this.color);
}

/// Analyze audio samples and compute frequency data per segment
/// This matches the JavaScript #analyzeAllFrequencies method
class FrequencyAnalyzer {
  static const double LOW_MAX = 1100;
  static const double HIGH_MIN = 2000;
  static const double ENERGY_THRESHOLD = 1e-6;

  /// Analyze audio and return frequency segments
  static List<FrequencySegment> analyze(
    Float64List signal,
    double sampleRate, {
    int? numSegments,
  }) {
    // Dynamic segment count based on audio length
    const minSamplesPerSegment = 256;
    var segCount = math.max(1, signal.length ~/ minSamplesPerSegment);
    // Cap segments to avoid excessive computation
    segCount = math.min(segCount, 2000);

    if (numSegments != null) {
      segCount = numSegments;
    }

    final samplesPerSegment = signal.length ~/ segCount;

    // Determine FFT size
    var fftSize = 2048;
    while (fftSize > samplesPerSegment && fftSize > 128) {
      fftSize ~/= 2;
    }

    final segments = <FrequencySegment>[];

    for (int seg = 0; seg < segCount; seg++) {
      final start = seg * samplesPerSegment;
      if (start >= signal.length) break;

      final buffer = Float64List(fftSize);
      double segMin = 1, segMax = -1;

      for (int j = 0; j < fftSize; j++) {
        final idx = start + j;
        if (idx >= signal.length) break;
        final val = signal[idx];
        if (val < segMin) segMin = val;
        if (val > segMax) segMax = val;
        // Apply Hann window
        final window = 0.5 * (1 - math.cos((2 * math.pi * j) / (fftSize - 1)));
        buffer[j] = val * window;
      }

      final fft = FFT(fftSize, sampleRate);
      final spectrum = fft.forward(buffer);

      double lowEnergy = 0, midEnergy = 0, highEnergy = 0;
      double totalEnergy = 0;

      final numBins = spectrum.length;
      for (int bin = 1; bin < numBins; bin++) {
        final mag = spectrum[bin];
        final power = mag * mag;
        final freq = (bin * sampleRate) / fftSize;
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
        segments.add(FrequencySegment(
          min: 0,
          max: 0,
          centroid: 500,
          lowEnergy: 0,
          midEnergy: 0,
          highEnergy: 0,
        ));
        continue;
      }

      lowEnergy /= totalEnergy;
      midEnergy /= totalEnergy;
      highEnergy /= totalEnergy;

      // Calculate spectral centroid (weighted average frequency)
      double weightedFreq = 0, totalMag = 0;
      for (int bin = 1; bin < numBins; bin++) {
        final mag = spectrum[bin];
        final freq = (bin * sampleRate) / fftSize;
        totalMag += mag;
        weightedFreq += freq * mag;
      }
      final centroid = totalMag > 0 ? weightedFreq / totalMag : 500.0;

      segments.add(FrequencySegment(
        min: segMin,
        max: segMax,
        centroid: centroid,
        lowEnergy: lowEnergy,
        midEnergy: midEnergy,
        highEnergy: highEnergy,
      ));
    }

    return segments;
  }
}
