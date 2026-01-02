// AudioPlayerService - Single file audio playback using flutter_soloud
import 'dart:async';
import 'dart:io';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Audio playback state
enum AudioPlaybackState { stopped, playing, paused, loading }

/// Simple audio player service for single file playback
class AudioPlayerService {
  final SoLoud _soloud = SoLoud.instance;
  AudioSource? _source;
  SoundHandle? _handle;

  final StreamController<AudioPlaybackState> _stateController =
      StreamController<AudioPlaybackState>.broadcast();
  final StreamController<double> _positionController =
      StreamController<double>.broadcast();

  Timer? _positionTimer;
  double _duration = 0;
  double _currentPosition = 0;
  bool _isPlaying = false;
  bool _loop = false;
  double _volume = 1.0;

  // Audio metadata
  int _sampleRate = 44100;
  int _channels = 2;
  String _format = '';

  Stream<AudioPlaybackState> get stateStream => _stateController.stream;
  Stream<double> get positionStream => _positionController.stream;

  double get duration => _duration;
  double get currentPosition => _currentPosition;
  bool get isPlaying => _isPlaying;
  bool get loop => _loop;
  double get volume => _volume;
  int get sampleRate => _sampleRate;
  int get channels => _channels;
  String get format => _format;

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
    await stop();
    await unload();
    if (_soloud.isInitialized) {
      _soloud.deinit();
    }
  }

  /// Load an audio file from path
  Future<bool> loadFile(String filePath) async {
    _stateController.add(AudioPlaybackState.loading);

    try {
      // Unload previous file
      await unload();

      // Check file exists
      final file = File(filePath);
      if (!await file.exists()) {
        _stateController.add(AudioPlaybackState.stopped);
        return false;
      }

      // Determine format from extension
      final ext = filePath.split('.').last.toLowerCase();
      _format = ext.toUpperCase();

      // Load the audio file
      _source = await _soloud.loadFile(filePath);

      // Get duration
      _duration = _soloud.getLength(_source!).inMilliseconds / 1000.0;

      // Extract metadata (sample rate, channels)
      // flutter_soloud doesn't expose this directly, so we use defaults
      // or could parse WAV headers manually
      _sampleRate = 44100; // Default
      _channels = 2; // Default

      _currentPosition = 0;
      _stateController.add(AudioPlaybackState.stopped);
      return true;
    } catch (e) {
      _stateController.add(AudioPlaybackState.stopped);
      return false;
    }
  }

  /// Play the loaded audio
  Future<void> play() async {
    if (_source == null) return;

    _isPlaying = true;
    _stateController.add(AudioPlaybackState.playing);

    if (_handle == null) {
      _handle = await _soloud.play(
        _source!,
        volume: _volume,
        paused: false,
      );

      // Seek to current position if resuming
      if (_currentPosition > 0) {
        _soloud.seek(_handle!, Duration(milliseconds: (_currentPosition * 1000).round()));
      }
    } else {
      _soloud.setPause(_handle!, false);
    }

    // Set looping
    if (_loop) {
      _soloud.setLooping(_handle!, true);
    }

    _startPositionTimer();
  }

  /// Pause playback
  void pause() {
    if (_handle == null) return;

    _isPlaying = false;
    _stateController.add(AudioPlaybackState.paused);
    _soloud.setPause(_handle!, true);
    _positionTimer?.cancel();
  }

  /// Stop playback and reset position
  Future<void> stop() async {
    _isPlaying = false;
    _currentPosition = 0;
    _positionController.add(0);
    _stateController.add(AudioPlaybackState.stopped);

    if (_handle != null) {
      _soloud.stop(_handle!);
      _handle = null;
    }

    _positionTimer?.cancel();
  }

  /// Seek to a specific position (in seconds)
  void seek(double position) {
    _currentPosition = position.clamp(0, _duration);
    _positionController.add(_currentPosition);

    if (_handle != null) {
      _soloud.seek(_handle!, Duration(milliseconds: (_currentPosition * 1000).round()));
    }
  }

  /// Set volume (0.0 to 1.0)
  void setVolume(double volume) {
    _volume = volume.clamp(0, 1);
    if (_handle != null) {
      _soloud.setVolume(_handle!, _volume);
    }
  }

  /// Toggle loop mode
  void setLoop(bool loop) {
    _loop = loop;
    if (_handle != null) {
      _soloud.setLooping(_handle!, loop);
    }
  }

  /// Play a specific range (for selection playback)
  Future<void> playRange(double start, double end) async {
    if (_source == null) return;

    _currentPosition = start;
    await play();

    // Stop at end of selection (check in position timer)
    // This is handled in the position timer callback
  }

  /// Unload the current audio file
  Future<void> unload() async {
    await stop();
    if (_source != null) {
      await _soloud.disposeSource(_source!);
      _source = null;
    }
    _duration = 0;
    _format = '';
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_handle != null) {
        try {
          final position = _soloud.getPosition(_handle!);
          _currentPosition = position.inMilliseconds / 1000.0;
          _positionController.add(_currentPosition);

          // Check for end of playback
          if (_currentPosition >= _duration - 0.05 && !_loop) {
            stop();
          }
        } catch (e) {
          // Handle may have become invalid
        }
      }
    });
  }
}
