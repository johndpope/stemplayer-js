import 'dart:typed_data';

/// Represents a single audio stem (e.g., Drums, Vocals, Bass, etc.)
class Stem {
  final String id;
  final String label;
  final String audioUrl;
  final String? waveformUrl;
  double volume;
  bool muted;
  bool solo;
  List<double>? peaks;
  Float64List? audioSamples;

  Stem({
    required this.id,
    required this.label,
    required this.audioUrl,
    this.waveformUrl,
    this.volume = 1.0,
    this.muted = false,
    this.solo = false,
    this.peaks,
    this.audioSamples,
  });

  Stem copyWith({
    String? id,
    String? label,
    String? audioUrl,
    String? waveformUrl,
    double? volume,
    bool? muted,
    bool? solo,
    List<double>? peaks,
    Float64List? audioSamples,
  }) {
    return Stem(
      id: id ?? this.id,
      label: label ?? this.label,
      audioUrl: audioUrl ?? this.audioUrl,
      waveformUrl: waveformUrl ?? this.waveformUrl,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      solo: solo ?? this.solo,
      peaks: peaks ?? this.peaks,
      audioSamples: audioSamples ?? this.audioSamples,
    );
  }

  /// Effective volume considering mute and solo states
  double get effectiveVolume => muted ? 0.0 : volume;
}

/// Waveform data structure containing peak values
class WaveformData {
  final List<double> peaks;
  final int sampleRate;
  final int samplesPerPixel;
  final int channels;

  WaveformData({
    required this.peaks,
    this.sampleRate = 44100,
    this.samplesPerPixel = 256,
    this.channels = 1,
  });

  /// Parse waveform data from JSON (audiowaveform format)
  factory WaveformData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>;
    final peaks = data.map((e) => (e as num).toDouble()).toList();

    return WaveformData(
      peaks: peaks,
      sampleRate: json['sample_rate'] as int? ?? 44100,
      samplesPerPixel: json['samples_per_pixel'] as int? ?? 256,
      channels: json['channels'] as int? ?? 1,
    );
  }

  /// Normalize peaks to -1 to 1 range
  List<double> get normalizedPeaks {
    if (peaks.isEmpty) return [];

    double maxAbs = 0;
    for (final peak in peaks) {
      if (peak.abs() > maxAbs) maxAbs = peak.abs();
    }

    if (maxAbs == 0) return peaks;

    return peaks.map((p) => p / maxAbs).toList();
  }

  /// Get min/max pairs for rendering
  List<WaveformBar> getBars() {
    final bars = <WaveformBar>[];
    final normalized = normalizedPeaks;

    for (int i = 0; i < normalized.length - 1; i += 2) {
      bars.add(WaveformBar(
        min: normalized[i],
        max: normalized[i + 1],
      ));
    }

    return bars;
  }
}

/// A single waveform bar with min/max values
class WaveformBar {
  final double min;
  final double max;

  const WaveformBar({required this.min, required this.max});

  double get height => (max - min).abs();
  double get center => (max + min) / 2;
}

/// Region selection for playback
class PlaybackRegion {
  final double startTime;
  final double endTime;

  const PlaybackRegion({
    required this.startTime,
    required this.endTime,
  });

  double get duration => endTime - startTime;

  bool contains(double time) => time >= startTime && time <= endTime;

  PlaybackRegion copyWith({double? startTime, double? endTime}) {
    return PlaybackRegion(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
