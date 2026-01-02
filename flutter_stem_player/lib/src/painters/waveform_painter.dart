import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../utils/fft.dart';

/// CustomPainter for rendering frequency-colored waveforms
/// Matches the JavaScript FcFrequencyWaveform implementation
class FrequencyWaveformPainter extends CustomPainter {
  final List<FrequencySegment> segments;
  final double progress;
  final double scaleY;
  final double audioDuration; // in seconds, for sparse rendering

  static const double AMPLITUDE_THRESHOLD = 0.01;

  FrequencyWaveformPainter({
    required this.segments,
    this.progress = 0,
    this.scaleY = 1.0,
    this.audioDuration = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final width = size.width;
    final height = size.height;
    final mid = height / 2;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFFF8F8F8),
    );

    // Center line
    canvas.drawLine(
      Offset(0, mid),
      Offset(width, mid),
      Paint()
        ..color = const Color(0xFFDDDDDD)
        ..strokeWidth = 1,
    );

    final numSegments = segments.length;

    // Calculate the proportion of width to use based on audio duration
    // Matching JS: const referenceDuration = 10;
    const referenceDuration = 10.0;
    final durationRatio =
        audioDuration > 0 ? (audioDuration / referenceDuration).clamp(0.0, 1.0) : 1.0;
    final usedWidth = width * durationRatio;
    final segmentWidth = usedWidth / numSegments;

    for (int i = 0; i < numSegments; i++) {
      final seg = segments[i];
      final x = i * segmentWidth;

      final amplitude =
          (seg.min.abs() > seg.max.abs() ? seg.min.abs() : seg.max.abs()) * scaleY;
      if (amplitude < AMPLITUDE_THRESHOLD) continue;

      final totalHeight = amplitude * mid * 0.95;
      if (totalHeight < 0.5) continue;

      // Get color from frequency centroid
      final rgb = getColorForFrequency(seg.centroid);
      final color = Color.fromRGBO(rgb[0], rgb[1], rgb[2], 1.0);

      // Draw with pink outer layer for high frequency content (matching JS)
      if (seg.highEnergy > 0.08) {
        const pink = Color.fromRGBO(240, 115, 185, 1.0);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(x + segmentWidth / 2, mid),
            width: segmentWidth + 0.3,
            height: totalHeight * 2,
          ),
          Paint()..color = pink,
        );

        // Inner layer
        final innerRatio = (0.55 - seg.highEnergy).clamp(0.25, 1.0);
        final innerHeight = totalHeight * innerRatio;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(x + segmentWidth / 2, mid),
            width: segmentWidth + 0.3,
            height: innerHeight * 2,
          ),
          Paint()..color = color,
        );
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(x + segmentWidth / 2, mid),
            width: segmentWidth + 0.3,
            height: totalHeight * 2,
          ),
          Paint()..color = color,
        );
      }
    }

    // Progress overlay (white semi-transparent over unplayed portion)
    if (progress > 0 && progress < 1) {
      final progressX = progress * width;
      canvas.drawRect(
        Rect.fromLTWH(progressX, 0, width - progressX, height),
        Paint()..color = const Color(0x4DFFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(covariant FrequencyWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.scaleY != scaleY ||
        oldDelegate.segments != segments;
  }
}

/// Simple waveform painter for peaks-only data (no frequency colors)
class SimpleWaveformPainter extends CustomPainter {
  final List<double> peaks; // [min, max, min, max, ...]
  final double progress;
  final double scaleY;
  final Color waveformColor;
  final Color progressColor;

  SimpleWaveformPainter({
    required this.peaks,
    this.progress = 0,
    this.scaleY = 1.0,
    this.waveformColor = const Color(0xB350B4A0),
    this.progressColor = const Color(0xFF6200EA),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;

    final width = size.width;
    final height = size.height;
    final mid = height / 2;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFFF8F8F8),
    );

    final numBars = peaks.length ~/ 2;
    final barWidth = width / numBars;

    for (int i = 0; i < numBars; i++) {
      final x = i * barWidth;
      final min = peaks[i * 2] * scaleY;
      final max = peaks[i * 2 + 1] * scaleY;

      final barHeight = ((max - min) / 2) * mid;
      final y = mid - max * mid;

      canvas.drawRect(
        Rect.fromLTWH(x, y, barWidth - 0.5, barHeight * 2),
        Paint()..color = waveformColor,
      );
    }

    // Progress overlay
    if (progress > 0) {
      final progressX = progress * width;
      canvas.drawRect(
        Rect.fromLTWH(progressX, 0, width - progressX, height),
        Paint()..color = const Color(0x4DFFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SimpleWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.scaleY != scaleY;
  }
}

/// Loading placeholder painter
class LoadingWaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF8F8F8),
    );

    // Center line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()
        ..color = const Color(0xFFDDDDDD)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
