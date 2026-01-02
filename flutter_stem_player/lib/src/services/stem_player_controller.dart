import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/stem.dart';
import '../utils/fft.dart';
import 'audio_service.dart';

/// Controller for the stem player, managing state and audio
class StemPlayerController extends ChangeNotifier {
  final StemAudioService _audioService = StemAudioService();
  final FrequencyAnalyzer _frequencyAnalyzer = FrequencyAnalyzer();

  final List<Stem> _stems = [];
  final Map<String, WaveformData> _waveforms = {};
  final Map<String, List<FrequencySegment>> _frequencyData = {};

  PlaybackState _playbackState = PlaybackState.stopped;
  double _currentPosition = 0;
  double _duration = 0;
  double _zoom = 1.0;
  bool _loop = false;
  bool _showFrequencyColors = true;
  PlaybackRegion? _region;

  StreamSubscription? _stateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _fftSubscription;

  // Getters
  List<Stem> get stems => List.unmodifiable(_stems);
  PlaybackState get playbackState => _playbackState;
  double get currentPosition => _currentPosition;
  double get duration => _duration;
  double get progress => _duration > 0 ? _currentPosition / _duration : 0;
  double get zoom => _zoom;
  bool get loop => _loop;
  bool get isPlaying => _playbackState == PlaybackState.playing;
  bool get isLoading => _playbackState == PlaybackState.loading;
  bool get showFrequencyColors => _showFrequencyColors;
  PlaybackRegion? get region => _region;

  WaveformData? getWaveform(String stemId) => _waveforms[stemId];
  List<FrequencySegment>? getFrequencyData(String stemId) => _frequencyData[stemId];

  /// Initialize the controller
  Future<void> init() async {
    await _audioService.init();

    _stateSubscription = _audioService.stateStream.listen((state) {
      _playbackState = state;
      notifyListeners();
    });

    _positionSubscription = _audioService.positionStream.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _fftSubscription?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  /// Add and load a stem
  Future<void> addStem(Stem stem) async {
    _stems.add(stem);
    notifyListeners();

    await _audioService.loadStem(stem);
    _duration = _audioService.duration;

    // Load waveform data if URL provided
    if (stem.waveformUrl != null) {
      await _loadWaveform(stem.id, stem.waveformUrl!);
    }

    notifyListeners();
  }

  /// Add multiple stems
  Future<void> addStems(List<Stem> stems) async {
    for (final stem in stems) {
      await addStem(stem);
    }
  }

  /// Load waveform data from URL
  Future<void> _loadWaveform(String stemId, String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final waveform = WaveformData.fromJson(json);
        _waveforms[stemId] = waveform;

        // Generate frequency data for visualization
        _generateFrequencyData(stemId, waveform);

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load waveform for $stemId: $e');
    }
  }

  /// Generate frequency color data from waveform
  void _generateFrequencyData(String stemId, WaveformData waveform) {
    // For now, generate mock frequency data based on peaks
    // In a real implementation, you'd analyze the actual audio samples
    final bars = waveform.getBars();
    final segments = <FrequencySegment>[];

    for (int i = 0; i < bars.length; i++) {
      final bar = bars[i];
      // Simulate frequency based on position and amplitude
      // This creates a visually interesting pattern
      final position = i / bars.length;
      final amplitude = bar.height;

      // Create varying frequencies across the waveform
      double frequency;
      if (amplitude > 0.7) {
        frequency = 100 + position * 300; // Bass-heavy for loud parts
      } else if (amplitude > 0.4) {
        frequency = 400 + position * 2000; // Mid frequencies
      } else {
        frequency = 2000 + position * 8000; // Higher frequencies for quiet parts
      }

      segments.add(FrequencySegment(
        dominantFrequency: frequency,
        magnitude: amplitude,
        lowEnergy: amplitude > 0.5 ? 0.6 : 0.2,
        midEnergy: 0.3,
        highEnergy: amplitude < 0.3 ? 0.5 : 0.1,
        color: FrequencyBands.getColorForFrequency(frequency),
      ));
    }

    _frequencyData[stemId] = segments;
  }

  /// Remove a stem
  Future<void> removeStem(String stemId) async {
    _stems.removeWhere((s) => s.id == stemId);
    _waveforms.remove(stemId);
    _frequencyData.remove(stemId);
    await _audioService.unloadStem(stemId);
    notifyListeners();
  }

  /// Play
  Future<void> play() async {
    await _audioService.play();
  }

  /// Pause
  void pause() {
    _audioService.pause();
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (isPlaying) {
      pause();
    } else {
      await play();
    }
  }

  /// Stop
  Future<void> stop() async {
    await _audioService.stopAll();
    _currentPosition = 0;
    notifyListeners();
  }

  /// Seek to position (0-1 progress or seconds)
  void seek(double position, {bool isProgress = true}) {
    if (isProgress) {
      _audioService.seek(position * _duration);
    } else {
      _audioService.seek(position);
    }
  }

  /// Set stem volume
  void setStemVolume(String stemId, double volume) {
    final index = _stems.indexWhere((s) => s.id == stemId);
    if (index >= 0) {
      _stems[index] = _stems[index].copyWith(volume: volume);
      _audioService.setStemVolume(stemId, volume);
      notifyListeners();
    }
  }

  /// Toggle stem mute
  void toggleStemMute(String stemId) {
    final index = _stems.indexWhere((s) => s.id == stemId);
    if (index >= 0) {
      _stems[index] = _stems[index].copyWith(muted: !_stems[index].muted);
      _audioService.toggleStemMute(stemId);
      notifyListeners();
    }
  }

  /// Toggle stem solo
  void toggleStemSolo(String stemId) {
    // Reset all solos first
    for (int i = 0; i < _stems.length; i++) {
      if (_stems[i].id != stemId) {
        _stems[i] = _stems[i].copyWith(solo: false);
      }
    }

    // Toggle target stem
    final index = _stems.indexWhere((s) => s.id == stemId);
    if (index >= 0) {
      _stems[index] = _stems[index].copyWith(solo: !_stems[index].solo);
    }

    _audioService.toggleStemSolo(stemId);
    notifyListeners();
  }

  /// Set zoom level
  void setZoom(double zoom) {
    _zoom = zoom.clamp(1.0, 10.0);
    notifyListeners();
  }

  /// Zoom in
  void zoomIn() {
    setZoom(_zoom + 0.5);
  }

  /// Zoom out
  void zoomOut() {
    setZoom(_zoom - 0.5);
  }

  /// Toggle loop
  void toggleLoop() {
    _loop = !_loop;
    _audioService.setLoop(_loop);
    notifyListeners();
  }

  /// Toggle frequency colors
  void toggleFrequencyColors() {
    _showFrequencyColors = !_showFrequencyColors;
    notifyListeners();
  }

  /// Set playback region
  void setRegion(PlaybackRegion? region) {
    _region = region;
    notifyListeners();
  }

  /// Format time as MM:SS or HH:MM:SS
  String formatTime(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Get combined peaks from all stems
  List<double>? getCombinedPeaks() {
    if (_waveforms.isEmpty) return null;

    final allBars = _waveforms.values.map((w) => w.getBars()).toList();
    if (allBars.isEmpty) return null;

    final maxLength = allBars.map((b) => b.length).reduce((a, b) => a > b ? a : b);
    final combined = <double>[];

    for (int i = 0; i < maxLength; i++) {
      double minVal = 0;
      double maxVal = 0;

      for (final bars in allBars) {
        if (i < bars.length) {
          minVal += bars[i].min;
          maxVal += bars[i].max;
        }
      }

      combined.add(minVal / allBars.length);
      combined.add(maxVal / allBars.length);
    }

    return combined;
  }
}
