import 'package:flutter/material.dart';

import '../models/stem.dart';
import '../painters/waveform_painter.dart';
import '../utils/fft.dart';

/// Waveform display widget with frequency coloring
class WaveformWidget extends StatelessWidget {
  final List<WaveformBar> bars;
  final List<FrequencySegment>? frequencySegments;
  final double progress;
  final double scaleY;
  final bool showFrequencyColors;
  final Color waveformColor;
  final Color progressColor;
  final ValueChanged<double>? onSeek;
  final double height;

  const WaveformWidget({
    super.key,
    required this.bars,
    this.frequencySegments,
    this.progress = 0,
    this.scaleY = 1.0,
    this.showFrequencyColors = true,
    this.waveformColor = const Color(0xFF424242),
    this.progressColor = const Color(0xFFFFFFFF),
    this.onSeek,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        if (onSeek != null) {
          final box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          final progress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
          onSeek!(progress);
        }
      },
      onHorizontalDragUpdate: (details) {
        if (onSeek != null) {
          final box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          final progress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
          onSeek!(progress);
        }
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CustomPaint(
            size: Size.infinite,
            painter: FrequencyWaveformPainter(
              bars: bars,
              frequencySegments: frequencySegments,
              progress: progress,
              scaleY: scaleY,
              showFrequencyColors: showFrequencyColors,
              waveformColor: waveformColor,
              progressColor: progressColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple waveform without frequency colors
class SimpleWaveformWidget extends StatelessWidget {
  final List<WaveformBar> bars;
  final double progress;
  final double scaleY;
  final Color waveformColor;
  final Color progressColor;
  final ValueChanged<double>? onSeek;
  final double height;

  const SimpleWaveformWidget({
    super.key,
    required this.bars,
    this.progress = 0,
    this.scaleY = 1.0,
    this.waveformColor = const Color(0xFF424242),
    this.progressColor = const Color(0xFF6200EA),
    this.onSeek,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        if (onSeek != null) {
          final box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          final progress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
          onSeek!(progress);
        }
      },
      onHorizontalDragUpdate: (details) {
        if (onSeek != null) {
          final box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          final progress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
          onSeek!(progress);
        }
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CustomPaint(
            size: Size.infinite,
            painter: SimpleWaveformPainter(
              bars: bars,
              progress: progress,
              scaleY: scaleY,
              waveformColor: waveformColor,
              progressColor: progressColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Real-time FFT visualizer widget
class FFTVisualizerWidget extends StatelessWidget {
  final List<double> fftData;
  final bool showFrequencyColors;
  final double height;

  const FFTVisualizerWidget({
    super.key,
    required this.fftData,
    this.showFrequencyColors = true,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          size: Size.infinite,
          painter: FFTVisualizerPainter(
            fftData: fftData,
            showFrequencyColors: showFrequencyColors,
          ),
        ),
      ),
    );
  }
}

/// Mirror waveform widget
class MirrorWaveformWidget extends StatelessWidget {
  final List<WaveformBar> bars;
  final List<FrequencySegment>? frequencySegments;
  final double progress;
  final double scaleY;
  final bool showFrequencyColors;
  final Color waveformColor;
  final ValueChanged<double>? onSeek;
  final double height;

  const MirrorWaveformWidget({
    super.key,
    required this.bars,
    this.frequencySegments,
    this.progress = 0,
    this.scaleY = 1.0,
    this.showFrequencyColors = true,
    this.waveformColor = const Color(0xFF424242),
    this.onSeek,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        if (onSeek != null) {
          final box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          final progress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
          onSeek!(progress);
        }
      },
      onHorizontalDragUpdate: (details) {
        if (onSeek != null) {
          final box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          final progress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
          onSeek!(progress);
        }
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CustomPaint(
            size: Size.infinite,
            painter: MirrorWaveformPainter(
              bars: bars,
              frequencySegments: frequencySegments,
              progress: progress,
              scaleY: scaleY,
              showFrequencyColors: showFrequencyColors,
              waveformColor: waveformColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder for waveform
class WaveformPlaceholder extends StatelessWidget {
  final double height;

  const WaveformPlaceholder({
    super.key,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}
