import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'src/utils/fft.dart';
import 'src/utils/wav_decoder.dart';
import 'src/painters/waveform_painter.dart';

void main() {
  runApp(const StemPlayerApp());
}

class StemPlayerApp extends StatelessWidget {
  const StemPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frequency Waveform - Demo Track',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: '.SF Pro Text',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3282B8),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const FrequencyTestPage(),
    );
  }
}

/// Stem configuration matching frequency-test.html
class StemConfig {
  final String name;
  final String file;
  const StemConfig(this.name, this.file);
}

// Local dev server URL - run 'npm start' in stemplayer-js root
const String baseUrl = 'http://localhost:8003/demo/assets/audio/';

const List<StemConfig> stemConfigs = [
  StemConfig('Drums A', '106 DRUMS A_02.5.m3u8'),
  StemConfig('Drums B', '106 DRUMS B_01.5.m3u8'),
  StemConfig('Conga', '106 CONGA_03.3.m3u8'),
  StemConfig('Cabasa', '106 CABASA_04.3.m3u8'),
  StemConfig('Bell', '106 BELL_05.3.m3u8'),
];

/// Frequency legend colors matching the HTML demo
class FrequencyLegend {
  static const List<LegendItem> items = [
    LegendItem('Bass', Color(0xFF64508C)),
    LegendItem('Low', Color(0xFF3C8CA0)),
    LegendItem('Mid', Color(0xFF64C864)),
    LegendItem('Upper', Color(0xFFF0DC64)),
    LegendItem('Presence', Color(0xFFFA9696)),
    LegendItem('High', Color(0xFFE664B4)),
    LegendItem('V.High', Color(0xFFC850C8)),
  ];
}

class LegendItem {
  final String label;
  final Color color;
  const LegendItem(this.label, this.color);
}

class FrequencyTestPage extends StatefulWidget {
  const FrequencyTestPage({super.key});

  @override
  State<FrequencyTestPage> createState() => _FrequencyTestPageState();
}

class _FrequencyTestPageState extends State<FrequencyTestPage> {
  final List<StemState> _stems = [];
  bool _isPlaying = false;
  double _currentTime = 0;
  double _duration = 0;
  int _loadedCount = 0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _initializeStems();
  }

  void _initializeStems() {
    // Create stem states
    for (int i = 0; i < stemConfigs.length; i++) {
      final config = stemConfigs[i];
      _stems.add(StemState(
        name: config.name,
        url: '$baseUrl${config.file}',
        index: i,
      ));
    }
    setState(() {});

    // Load stems
    for (int i = 0; i < _stems.length; i++) {
      _loadStem(i);
    }
  }

  /// Parse m3u8 playlist and return segment URLs
  Future<List<String>> _parseM3u8(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final baseDir = url.substring(0, url.lastIndexOf('/') + 1);
    final segments = <String>[];

    for (final line in response.body.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        segments.add(baseDir + trimmed);
      }
    }
    return segments;
  }

  Future<void> _loadStem(int index) async {
    final stemState = _stems[index];

    try {
      debugPrint('Loading ${stemState.name}...');

      List<Float64List> allSamples = [];
      double sampleRate = 44100;

      // Check if it's an m3u8 playlist
      if (stemState.url.endsWith('.m3u8')) {
        final segmentUrls = await _parseM3u8(stemState.url);

        for (final segUrl in segmentUrls) {
          final response = await http.get(Uri.parse(segUrl));
          if (response.statusCode != 200) {
            debugPrint('Failed to load segment: $segUrl');
            continue;
          }

          // Decode MP3 segment (simplified - treats as raw PCM for now)
          // TODO: Add proper MP3 decoding support
          // For now, skip mp3 and mark as loaded with empty data
          debugPrint('Loaded segment: $segUrl (${response.bodyBytes.length} bytes)');
        }

        // For now, mark as loaded but without frequency data (mp3 decoding needed)
        stemState.frequencySegments = [];
        stemState.isLoaded = true;
        stemState.audioDuration = 73.0; // Approximate duration
        if (stemState.audioDuration > _duration) {
          _duration = stemState.audioDuration;
        }
      } else {
        // Download WAV file
        final response = await http.get(Uri.parse(stemState.url));
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }

        // Decode WAV
        final wav = WavDecoder(response.bodyBytes);
        stemState.sampleRate = wav.sampleRate.toDouble();
        stemState.audioDuration = wav.duration;

        // Update max duration
        if (wav.duration > _duration) {
          _duration = wav.duration;
        }

        // Analyze frequencies using FFT (matching JS implementation)
        stemState.frequencySegments = FrequencyAnalyzer.analyze(
          wav.samples,
          stemState.sampleRate,
        );

        stemState.isLoaded = true;

        // Debug: print first few segment values to verify uniqueness
        final segs = stemState.frequencySegments!;
        if (segs.isNotEmpty) {
          final first = segs.first;
          final mid = segs[segs.length ~/ 2];
          debugPrint('Loaded ${stemState.name}: ${wav.duration.toStringAsFixed(1)}s, ${segs.length} segments');
          debugPrint('  First seg: centroid=${first.centroid.toStringAsFixed(0)}, min=${first.min.toStringAsFixed(3)}, max=${first.max.toStringAsFixed(3)}');
          debugPrint('  Mid seg: centroid=${mid.centroid.toStringAsFixed(0)}, min=${mid.min.toStringAsFixed(3)}, max=${mid.max.toStringAsFixed(3)}');
        }
      }

      setState(() {
        _loadedCount++;
      });
    } catch (e) {
      debugPrint('Error loading ${stemState.name}: $e');
      // Mark as loaded but with empty data
      stemState.frequencySegments = [];
      stemState.isLoaded = true;
      setState(() {
        _loadedCount++;
      });
    }
  }

  void _togglePlayPause() {
    if (_loadedCount == 0) return;

    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  void _play() {
    setState(() => _isPlaying = true);
    _startProgressTimer();
  }

  void _pause() {
    setState(() => _isPlaying = false);
    _progressTimer?.cancel();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    final startRealTime = DateTime.now();
    final startPosition = _currentTime;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isPlaying) return;

      final elapsed = DateTime.now().difference(startRealTime).inMilliseconds / 1000.0;
      final newTime = startPosition + elapsed;

      if (newTime >= _duration) {
        _pause();
        setState(() => _currentTime = 0);
        return;
      }

      setState(() => _currentTime = newTime);
    });
  }

  void _seek(double progress) {
    final seekTime = progress * _duration;
    setState(() => _currentTime = seekTime);

    if (_isPlaying) {
      _progressTimer?.cancel();
      _startProgressTimer();
    }
  }

  void _toggleMute(int index) {
    setState(() {
      _stems[index].muted = !_stems[index].muted;
      _updateGains();
    });
  }

  void _toggleSolo(int index) {
    setState(() {
      _stems[index].solo = !_stems[index].solo;
      _updateGains();
    });
  }

  void _setVolume(int index, double volume) {
    setState(() {
      _stems[index].volume = volume;
      _updateGains();
    });
  }

  void _updateGains() {
    final anySoloed = _stems.any((s) => s.solo);
    for (final stem in _stems) {
      if (stem.muted) {
        stem.effectiveVolume = 0;
      } else if (anySoloed && !stem.solo) {
        stem.effectiveVolume = 0;
      } else {
        stem.effectiveVolume = stem.volume;
      }
    }
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              _buildLegend(),
              _buildControlsBar(),
              Expanded(child: _buildStemsList()),
            ],
          ),
          // Loading toast
          if (_loadedCount < stemConfigs.length)
            Positioned(
              bottom: 20,
              right: 20,
              child: _buildLoadingToast(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Frequency Waveform - Demo Track',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Waveforms colored by dominant frequency (Comparisonics): dark blue for bass, lighter blues/greens for mid-range, yellows/reds for highs.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8F8),
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: FrequencyLegend.items.map((item) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(item.label, style: const TextStyle(fontSize: 12)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildControlsBar() {
    final progress = _duration > 0 ? _currentTime / _duration : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: const Color(0xFF1A1A2E),
      child: Row(
        children: [
          // Play button
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF3282B8),
              ),
              child: Center(
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Time display
          Text(
            '${_formatTime(_currentTime)} / ${_formatTime(_duration)}',
            style: const TextStyle(
              fontFamily: 'Menlo',
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          // Progress bar
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    final pct = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                    _seek(pct);
                  },
                  onHorizontalDragUpdate: (details) {
                    final pct = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                    _seek(pct);
                  },
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF3282B8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStemsList() {
    return ListView.builder(
      itemCount: _stems.length,
      itemBuilder: (context, index) => _buildStemRow(index),
    );
  }

  Widget _buildStemRow(int index) {
    final stem = _stems[index];
    final progress = _duration > 0 ? _currentTime / _duration : 0.0;

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          // Controls
          Container(
            width: 230,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFFF5F5F5),
            child: Row(
              children: [
                // Solo button
                _buildControlButton(
                  'S',
                  stem.solo,
                  () => _toggleSolo(index),
                  activeColor: const Color(0xFFF0AD4E),
                ),
                const SizedBox(width: 4),
                // Mute button
                GestureDetector(
                  onTap: () => _toggleMute(index),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    child: Icon(
                      stem.muted ? Icons.volume_off : Icons.volume_up,
                      size: 18,
                      color: stem.muted ? const Color(0xFFD62828) : Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Volume slider
                SizedBox(
                  width: 60,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: const Color(0xFF3282B8),
                      inactiveTrackColor: const Color(0xFFCCCCCC),
                      thumbColor: const Color(0xFF3282B8),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: stem.volume,
                      onChanged: (v) => _setVolume(index, v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Stem name
                Expanded(
                  child: Text(
                    stem.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Waveform
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    final pct = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                    _seek(pct);
                  },
                  onHorizontalDragUpdate: (details) {
                    final pct = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                    _seek(pct);
                  },
                  child: stem.isLoaded && stem.frequencySegments != null && stem.frequencySegments!.isNotEmpty
                      ? CustomPaint(
                          size: Size(constraints.maxWidth, 60),
                          painter: FrequencyWaveformPainter(
                            segments: stem.frequencySegments!,
                            progress: progress,
                            scaleY: stem.effectiveVolume,
                            audioDuration: stem.audioDuration,
                          ),
                        )
                      : CustomPaint(
                          size: Size(constraints.maxWidth, 60),
                          painter: LoadingWaveformPainter(),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    String label,
    bool isActive,
    VoidCallback onTap, {
    Color activeColor = const Color(0xFF3282B8),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.black : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingToast() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF3282B8),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Loading stems: ',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          Text(
            '$_loadedCount',
            style: const TextStyle(
              color: Color(0xFF3282B8),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            ' / ${stemConfigs.length}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// State for each stem
class StemState {
  final String name;
  final String url;
  final int index;
  bool isLoaded = false;
  bool muted = false;
  bool solo = false;
  double volume = 1.0;
  double effectiveVolume = 1.0;
  double sampleRate = 44100;
  double audioDuration = 0;
  List<FrequencySegment>? frequencySegments;

  StemState({
    required this.name,
    required this.url,
    required this.index,
  });
}
