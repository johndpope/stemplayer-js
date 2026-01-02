import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/stem.dart';
import '../utils/fft.dart';

/// Audio playback state
enum PlaybackState { stopped, playing, paused, loading }

/// Audio service using flutter_soloud for multi-stem playback
class StemAudioService {
  final SoLoud _soloud = SoLoud.instance;
  final Map<String, _StemHandle> _stems = {};
  final StreamController<PlaybackState> _stateController =
      StreamController<PlaybackState>.broadcast();
  final StreamController<double> _positionController =
      StreamController<double>.broadcast();
  final StreamController<Map<String, Float64List>> _fftDataController =
      StreamController<Map<String, Float64List>>.broadcast();

  Timer? _positionTimer;
  double _duration = 0;
  double _currentPosition = 0;
  bool _isPlaying = false;
  bool _loop = false;
  double _masterVolume = 1.0;

  Stream<PlaybackState> get stateStream => _stateController.stream;
  Stream<double> get positionStream => _positionController.stream;
  Stream<Map<String, Float64List>> get fftDataStream => _fftDataController.stream;

  double get duration => _duration;
  double get currentPosition => _currentPosition;
  bool get isPlaying => _isPlaying;
  bool get loop => _loop;
  double get masterVolume => _masterVolume;

  /// Initialize the audio engine
  Future<void> init() async {
    if (!_soloud.isInitialized) {
      await _soloud.init();
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    _positionTimer?.cancel();
    await _stateController.close();
    await _positionController.close();
    await _fftDataController.close();
    await stopAll();
    if (_soloud.isInitialized) {
      _soloud.deinit();
    }
  }

  /// Load a stem from URL or file path
  Future<void> loadStem(Stem stem) async {
    _stateController.add(PlaybackState.loading);

    try {
      String filePath;

      if (stem.audioUrl.startsWith('http')) {
        // Download the file
        filePath = await _downloadAudio(stem.id, stem.audioUrl);
      } else {
        filePath = stem.audioUrl;
      }

      final source = await _soloud.loadFile(filePath);
      _stems[stem.id] = _StemHandle(
        stem: stem,
        source: source,
        handle: null,
      );

      // Get duration from first loaded stem
      if (_duration == 0) {
        _duration = _soloud.getLength(source).inMilliseconds / 1000.0;
      }

      _stateController.add(PlaybackState.stopped);
    } catch (e) {
      _stateController.add(PlaybackState.stopped);
      rethrow;
    }
  }

  /// Download audio file and return local path
  Future<String> _downloadAudio(String id, String url) async {
    final tempDir = await getTemporaryDirectory();
    final extension = path.extension(url).split('?').first;
    final filePath = path.join(tempDir.path, 'stem_$id$extension');

    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } else {
      throw Exception('Failed to download audio: ${response.statusCode}');
    }
  }

  /// Load multiple stems concurrently
  Future<void> loadStems(List<Stem> stems) async {
    _stateController.add(PlaybackState.loading);
    await Future.wait(stems.map((stem) => loadStem(stem)));
    _stateController.add(PlaybackState.stopped);
  }

  /// Play all loaded stems synchronized
  Future<void> play() async {
    if (_stems.isEmpty) return;

    _isPlaying = true;
    _stateController.add(PlaybackState.playing);

    for (final entry in _stems.entries) {
      final stemHandle = entry.value;
      if (stemHandle.handle == null) {
        final handle = await _soloud.play(
          stemHandle.source,
          volume: _calculateVolume(stemHandle),
          paused: false,
        );
        stemHandle.handle = handle;

        // Seek to current position for sync
        if (_currentPosition > 0) {
          _soloud.seek(handle, Duration(milliseconds: (_currentPosition * 1000).round()));
        }
      } else {
        _soloud.setPause(stemHandle.handle!, false);
      }
    }

    // Enable looping
    if (_loop) {
      for (final entry in _stems.entries) {
        if (entry.value.handle != null) {
          _soloud.setLooping(entry.value.handle!, true);
        }
      }
    }

    _startPositionTimer();
  }

  /// Pause all stems
  void pause() {
    _isPlaying = false;
    _stateController.add(PlaybackState.paused);

    for (final entry in _stems.entries) {
      if (entry.value.handle != null) {
        _soloud.setPause(entry.value.handle!, true);
      }
    }

    _positionTimer?.cancel();
  }

  /// Stop all stems and reset position
  Future<void> stopAll() async {
    _isPlaying = false;
    _currentPosition = 0;
    _positionController.add(0);
    _stateController.add(PlaybackState.stopped);

    for (final entry in _stems.entries) {
      if (entry.value.handle != null) {
        _soloud.stop(entry.value.handle!);
        entry.value.handle = null;
      }
    }

    _positionTimer?.cancel();
  }

  /// Seek to a specific position (in seconds)
  void seek(double position) {
    _currentPosition = position.clamp(0, _duration);
    _positionController.add(_currentPosition);

    final duration = Duration(milliseconds: (_currentPosition * 1000).round());
    for (final entry in _stems.entries) {
      if (entry.value.handle != null) {
        _soloud.seek(entry.value.handle!, duration);
      }
    }
  }

  /// Set volume for a specific stem
  void setStemVolume(String stemId, double volume) {
    final stemHandle = _stems[stemId];
    if (stemHandle != null) {
      stemHandle.stem.volume = volume.clamp(0, 1);
      _updateStemVolume(stemHandle);
    }
  }

  /// Toggle mute for a specific stem
  void toggleStemMute(String stemId) {
    final stemHandle = _stems[stemId];
    if (stemHandle != null) {
      stemHandle.stem.muted = !stemHandle.stem.muted;
      _updateStemVolume(stemHandle);
    }
  }

  /// Toggle solo for a specific stem (mutes all others)
  void toggleStemSolo(String stemId) {
    final stemHandle = _stems[stemId];
    if (stemHandle == null) return;

    final wasSolo = stemHandle.stem.solo;

    // Reset all solos first
    for (final entry in _stems.entries) {
      entry.value.stem.solo = false;
    }

    // Set solo on target if it wasn't already solo
    if (!wasSolo) {
      stemHandle.stem.solo = true;
    }

    // Update all volumes
    _updateAllVolumes();
  }

  /// Set master volume
  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0, 1);
    _updateAllVolumes();
  }

  /// Toggle loop mode
  void setLoop(bool loop) {
    _loop = loop;
    for (final entry in _stems.entries) {
      if (entry.value.handle != null) {
        _soloud.setLooping(entry.value.handle!, loop);
      }
    }
  }

  /// Get FFT data for a stem (for visualization)
  /// Note: Real-time FFT visualization requires flutter_soloud 3.x+
  Float64List? getFFTData(String stemId) {
    // FFT data retrieval simplified for compatibility
    // In flutter_soloud 3.x, use _soloud.getAudioTexture2D(source)
    return null;
  }

  /// Calculate effective volume for a stem
  double _calculateVolume(_StemHandle stemHandle) {
    final stem = stemHandle.stem;

    // Check if any stem is in solo mode
    final hasSolo = _stems.values.any((s) => s.stem.solo);

    if (hasSolo && !stem.solo) {
      return 0; // Mute non-solo stems when something is soloed
    }

    if (stem.muted) {
      return 0;
    }

    return stem.volume * _masterVolume;
  }

  double _calculateVolume_(Stem stem) {
    final hasSolo = _stems.values.any((s) => s.stem.solo);

    if (hasSolo && !stem.solo) {
      return 0;
    }

    if (stem.muted) {
      return 0;
    }

    return stem.volume * _masterVolume;
  }

  void _updateStemVolume(_StemHandle stemHandle) {
    if (stemHandle.handle != null) {
      _soloud.setVolume(stemHandle.handle!, _calculateVolume(stemHandle));
    }
  }

  void _updateAllVolumes() {
    for (final entry in _stems.entries) {
      _updateStemVolume(entry.value);
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_stems.isNotEmpty) {
        // Get position from first active handle
        for (final entry in _stems.entries) {
          if (entry.value.handle != null) {
            try {
              final position = _soloud.getPosition(entry.value.handle!);
              _currentPosition = position.inMilliseconds / 1000.0;
              _positionController.add(_currentPosition);

              // Check for end of playback
              if (_currentPosition >= _duration - 0.1 && !_loop) {
                stopAll();
              }
              break;
            } catch (e) {
              // Handle may have become invalid
            }
          }
        }

        // Emit FFT data for visualization
        final fftData = <String, Float64List>{};
        for (final entry in _stems.entries) {
          final data = getFFTData(entry.key);
          if (data != null) {
            fftData[entry.key] = data;
          }
        }
        if (fftData.isNotEmpty) {
          _fftDataController.add(fftData);
        }
      }
    });
  }

  /// Unload a specific stem
  Future<void> unloadStem(String stemId) async {
    final stemHandle = _stems.remove(stemId);
    if (stemHandle != null) {
      if (stemHandle.handle != null) {
        _soloud.stop(stemHandle.handle!);
      }
      await _soloud.disposeSource(stemHandle.source);
    }
  }

  /// Unload all stems
  Future<void> unloadAll() async {
    await stopAll();
    for (final entry in _stems.entries) {
      await _soloud.disposeSource(entry.value.source);
    }
    _stems.clear();
    _duration = 0;
  }
}

/// Internal class to hold stem audio handles
class _StemHandle {
  final Stem stem;
  final AudioSource source;
  SoundHandle? handle;

  _StemHandle({
    required this.stem,
    required this.source,
    this.handle,
  });
}
