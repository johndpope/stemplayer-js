import 'dart:typed_data';
import 'dart:math' as math;

/// WAV file decoder for extracting audio samples
class WavDecoder {
  final Uint8List data;
  late int sampleRate;
  late int channels;
  late int bitsPerSample;
  late int dataOffset;
  late int dataSize;
  late Float64List samples;

  WavDecoder(this.data) {
    _parse();
  }

  void _parse() {
    // Check RIFF header
    final riff = String.fromCharCodes(data.sublist(0, 4));
    if (riff != 'RIFF') {
      throw FormatException('Not a valid WAV file: missing RIFF header');
    }

    final wave = String.fromCharCodes(data.sublist(8, 12));
    if (wave != 'WAVE') {
      throw FormatException('Not a valid WAV file: missing WAVE format');
    }

    // Parse chunks
    int offset = 12;
    while (offset < data.length - 8) {
      final chunkId = String.fromCharCodes(data.sublist(offset, offset + 4));
      final chunkSize = _readUint32LE(offset + 4);

      if (chunkId == 'fmt ') {
        _parseFmtChunk(offset + 8);
      } else if (chunkId == 'data') {
        dataOffset = offset + 8;
        dataSize = chunkSize;
        break;
      }

      offset += 8 + chunkSize;
      // Align to even byte
      if (chunkSize % 2 != 0) offset++;
    }

    _extractSamples();
  }

  void _parseFmtChunk(int offset) {
    final audioFormat = _readUint16LE(offset);
    if (audioFormat != 1 && audioFormat != 3) {
      throw FormatException('Unsupported audio format: $audioFormat (only PCM supported)');
    }

    channels = _readUint16LE(offset + 2);
    sampleRate = _readUint32LE(offset + 4);
    bitsPerSample = _readUint16LE(offset + 14);
  }

  void _extractSamples() {
    final bytesPerSample = bitsPerSample ~/ 8;
    final numSamples = dataSize ~/ (bytesPerSample * channels);
    final mixedSamples = Float64List(numSamples);

    int sampleIndex = 0;
    int byteOffset = dataOffset;

    for (int i = 0; i < numSamples; i++) {
      double mixedValue = 0;

      for (int ch = 0; ch < channels; ch++) {
        double value;

        if (bitsPerSample == 8) {
          // 8-bit unsigned
          value = (data[byteOffset] - 128) / 128.0;
          byteOffset += 1;
        } else if (bitsPerSample == 16) {
          // 16-bit signed little-endian
          int raw = data[byteOffset] | (data[byteOffset + 1] << 8);
          if (raw >= 32768) raw -= 65536;
          value = raw / 32768.0;
          byteOffset += 2;
        } else if (bitsPerSample == 24) {
          // 24-bit signed little-endian
          int raw = data[byteOffset] |
              (data[byteOffset + 1] << 8) |
              (data[byteOffset + 2] << 16);
          if (raw >= 8388608) raw -= 16777216;
          value = raw / 8388608.0;
          byteOffset += 3;
        } else if (bitsPerSample == 32) {
          // 32-bit signed little-endian or float
          int raw = data[byteOffset] |
              (data[byteOffset + 1] << 8) |
              (data[byteOffset + 2] << 16) |
              (data[byteOffset + 3] << 24);
          value = raw / 2147483648.0;
          byteOffset += 4;
        } else {
          throw FormatException('Unsupported bits per sample: $bitsPerSample');
        }

        mixedValue += value;
      }

      // Mix down to mono
      mixedSamples[sampleIndex++] = mixedValue / channels;
    }

    samples = mixedSamples;
  }

  int _readUint16LE(int offset) {
    return data[offset] | (data[offset + 1] << 8);
  }

  int _readUint32LE(int offset) {
    return data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
  }

  /// Extract peaks (min/max pairs) from samples
  List<double> extractPeaks(int numBars) {
    final samplesPerBar = samples.length ~/ numBars;
    final peaks = <double>[];

    for (int i = 0; i < numBars; i++) {
      final start = i * samplesPerBar;
      final end = math.min(start + samplesPerBar, samples.length);

      double min = 1.0;
      double max = -1.0;

      for (int j = start; j < end; j++) {
        final sample = samples[j];
        if (sample < min) min = sample;
        if (sample > max) max = sample;
      }

      peaks.add(min);
      peaks.add(max);
    }

    return peaks;
  }

  /// Get duration in seconds
  double get duration => samples.length / sampleRate;
}
