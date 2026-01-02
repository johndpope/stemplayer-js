import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stem.dart';
import '../services/stem_player_controller.dart';
import '../utils/fft.dart';
import 'player_controls.dart';
import 'stem_row.dart';
import 'waveform_widget.dart';

/// Main stem player widget
class StemPlayer extends StatefulWidget {
  final List<Stem> stems;
  final bool autoplay;
  final bool loop;
  final bool showMasterWaveform;
  final double? maxHeight;
  final Color? backgroundColor;
  final VoidCallback? onEnd;

  const StemPlayer({
    super.key,
    required this.stems,
    this.autoplay = false,
    this.loop = false,
    this.showMasterWaveform = true,
    this.maxHeight,
    this.backgroundColor,
    this.onEnd,
  });

  @override
  State<StemPlayer> createState() => _StemPlayerState();
}

class _StemPlayerState extends State<StemPlayer> {
  late final StemPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = StemPlayerController();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    await _controller.init();

    // Load stems
    for (final stem in widget.stems) {
      await _controller.addStem(stem);
    }

    if (widget.loop) {
      _controller.toggleLoop();
    }

    setState(() {
      _isInitialized = true;
    });

    if (widget.autoplay) {
      await _controller.play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StemPlayerController>.value(
      value: _controller,
      child: Consumer<StemPlayerController>(
        builder: (context, controller, child) {
          return _StemPlayerContent(
            controller: controller,
            isInitialized: _isInitialized,
            showMasterWaveform: widget.showMasterWaveform,
            maxHeight: widget.maxHeight,
            backgroundColor: widget.backgroundColor,
          );
        },
      ),
    );
  }
}

class _StemPlayerContent extends StatelessWidget {
  final StemPlayerController controller;
  final bool isInitialized;
  final bool showMasterWaveform;
  final double? maxHeight;
  final Color? backgroundColor;

  const _StemPlayerContent({
    required this.controller,
    required this.isInitialized,
    this.showMasterWaveform = true,
    this.maxHeight,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return Container(
          constraints: maxHeight != null
              ? BoxConstraints(maxHeight: maxHeight!)
              : null,
          decoration: BoxDecoration(
            color: backgroundColor ?? theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Loading overlay
              if (!isInitialized || controller.isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // Master waveform (combined)
                if (showMasterWaveform) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildMasterWaveform(context),
                  ),
                  Divider(
                    height: 1,
                    color: theme.dividerColor.withOpacity(0.1),
                  ),
                ],
                // Stem rows
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: controller.stems.map((stem) {
                        final waveform = controller.getWaveform(stem.id);
                        final frequencyData = controller.getFrequencyData(stem.id);

                        return StemRow(
                          stem: stem,
                          waveform: waveform,
                          frequencySegments: frequencyData,
                          progress: controller.progress,
                          showFrequencyColors: controller.showFrequencyColors,
                          isCompact: isCompact,
                          onMuteToggle: () => controller.toggleStemMute(stem.id),
                          onSoloToggle: () => controller.toggleStemSolo(stem.id),
                          onVolumeChanged: (v) => controller.setStemVolume(stem.id, v),
                          onSeek: (p) => controller.seek(p),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Controls
                PlayerControls(
                  isPlaying: controller.isPlaying,
                  isLoading: controller.isLoading,
                  loop: controller.loop,
                  showFrequencyColors: controller.showFrequencyColors,
                  progress: controller.progress,
                  currentTime: controller.currentPosition,
                  duration: controller.duration,
                  zoom: controller.zoom,
                  isCompact: isCompact,
                  onPlayPause: controller.togglePlayPause,
                  onStop: controller.stop,
                  onLoopToggle: controller.toggleLoop,
                  onFrequencyColorsToggle: controller.toggleFrequencyColors,
                  onZoomIn: controller.zoomIn,
                  onZoomOut: controller.zoomOut,
                  onSeek: (p) => controller.seek(p),
                  formatTime: controller.formatTime,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMasterWaveform(BuildContext context) {
    // Combine all waveforms
    final allBars = <WaveformBar>[];

    for (final stem in controller.stems) {
      final waveform = controller.getWaveform(stem.id);
      if (waveform != null) {
        final bars = waveform.getBars();
        if (allBars.isEmpty) {
          allBars.addAll(bars);
        } else {
          // Merge bars (average)
          for (int i = 0; i < bars.length && i < allBars.length; i++) {
            allBars[i] = WaveformBar(
              min: (allBars[i].min + bars[i].min) / 2,
              max: (allBars[i].max + bars[i].max) / 2,
            );
          }
        }
      }
    }

    if (allBars.isEmpty) {
      return const WaveformPlaceholder(height: 80);
    }

    // Combine frequency data
    final allFrequencies = controller.stems
        .map((s) => controller.getFrequencyData(s.id))
        .whereType<List<FrequencySegment>>()
        .toList();

    return MirrorWaveformWidget(
      bars: allBars,
      frequencySegments: allFrequencies.isNotEmpty
          ? allFrequencies.first
          : null,
      progress: controller.progress,
      showFrequencyColors: controller.showFrequencyColors,
      onSeek: (p) => controller.seek(p),
      height: 80,
    );
  }
}

/// Standalone stem player using controller directly
class StemPlayerWithController extends StatelessWidget {
  final StemPlayerController controller;
  final bool showMasterWaveform;
  final double? maxHeight;
  final Color? backgroundColor;

  const StemPlayerWithController({
    super.key,
    required this.controller,
    this.showMasterWaveform = true,
    this.maxHeight,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StemPlayerController>.value(
      value: controller,
      child: Consumer<StemPlayerController>(
        builder: (context, ctrl, _) {
          return _StemPlayerContent(
            controller: ctrl,
            isInitialized: true,
            showMasterWaveform: showMasterWaveform,
            maxHeight: maxHeight,
            backgroundColor: backgroundColor,
          );
        },
      ),
    );
  }
}
