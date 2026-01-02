// SpectralWaveformView - Frequency-colored waveform display matching AudioFileView Python app
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'frequency_legend.dart';

class SpectralWaveformView extends StatefulWidget {
  final String? filePath;
  final double duration;
  final double position;
  final double selectionStart;
  final double selectionEnd;
  final ValueChanged<double>? onPositionTap;
  final void Function(double start, double end)? onSelectionChanged;
  /// Called when user wants to find similar sounds - passes selection range
  final void Function(double selectionStart, double selectionEnd)? onFindSimilar;

  const SpectralWaveformView({
    super.key,
    this.filePath,
    this.duration = 0,
    this.position = 0,
    this.selectionStart = 0,
    this.selectionEnd = 0,
    this.onPositionTap,
    this.onSelectionChanged,
    this.onFindSimilar,
  });

  @override
  State<SpectralWaveformView> createState() => _SpectralWaveformViewState();
}

class _SpectralWaveformViewState extends State<SpectralWaveformView> {
  // Waveform data - will be populated when audio is loaded
  List<WaveformSegment> _segments = [];

  // Zoom and pan
  double _zoom = 1.0;
  double _scrollOffset = 0.0;

  // Selection state
  bool _isDragging = false;
  double _dragStart = 0;

  // Track if secondary button is pressed to avoid clearing selection
  bool _isSecondaryButton = false;

  @override
  void didUpdateWidget(SpectralWaveformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filePath != oldWidget.filePath) {
      _loadWaveformData();
    }
  }

  void _loadWaveformData() {
    // TODO: Load actual waveform data from audio file
    // For now, generate demo data
    if (widget.filePath == null || widget.duration <= 0) {
      setState(() => _segments = []);
      return;
    }

    // Generate demo frequency-colored segments
    final random = math.Random(42);
    final segmentCount = (widget.duration * 100).toInt().clamp(100, 5000);
    final segments = <WaveformSegment>[];

    for (int i = 0; i < segmentCount; i++) {
      // Simulate frequency variation over time
      final t = i / segmentCount;
      final baseFreq = 200 + (t * 800); // Rising frequency trend
      final freq = baseFreq + random.nextDouble() * 500 - 250;
      final amplitude = 0.3 + random.nextDouble() * 0.5;

      segments.add(WaveformSegment(
        amplitude: amplitude,
        frequency: freq.clamp(20, 20000),
      ));
    }

    setState(() => _segments = segments);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            // Track if this is a right-click (secondary button)
            _isSecondaryButton = event.buttons == kSecondaryMouseButton;
          },
          onPointerUp: (event) {
            _isSecondaryButton = false;
          },
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              _onScroll(event);
            }
          },
          child: GestureDetector(
            onTapDown: _onTapDown,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onSecondaryTapDown: _showContextMenu,
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: Container(
                color: const Color(0xFF1e1e23),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: SpectralWaveformPainter(
                    segments: _segments,
                    duration: widget.duration,
                    position: widget.position,
                    selectionStart: widget.selectionStart,
                    selectionEnd: widget.selectionEnd,
                    zoom: _zoom,
                    scrollOffset: _scrollOffset,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onTapDown(TapDownDetails details) {
    // Don't handle right-clicks here - let context menu handle it
    if (_isSecondaryButton) return;
    if (widget.duration <= 0) return;
    final position = _pixelToTime(details.localPosition.dx);
    widget.onPositionTap?.call(position);
  }

  void _onPanStart(DragStartDetails details) {
    // Don't start drag on right-click
    if (_isSecondaryButton) return;
    if (widget.duration <= 0) return;
    _isDragging = true;
    _dragStart = _pixelToTime(details.localPosition.dx);
    widget.onSelectionChanged?.call(_dragStart, _dragStart);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || widget.duration <= 0) return;
    final dragEnd = _pixelToTime(details.localPosition.dx);
    final start = math.min(_dragStart, dragEnd);
    final end = math.max(_dragStart, dragEnd);
    widget.onSelectionChanged?.call(start, end);
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
  }

  void _onScroll(PointerScrollEvent event) {
    if (event.scrollDelta.dy < 0) {
      // Zoom in
      setState(() {
        _zoom = (_zoom * 1.1).clamp(1.0, 50.0);
      });
    } else {
      // Zoom out
      setState(() {
        _zoom = (_zoom / 1.1).clamp(1.0, 50.0);
      });
    }
  }

  void _showContextMenu(TapDownDetails details) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF2d2d2d),
      items: [
        const PopupMenuItem<String>(
          value: 'find_similar',
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: Color(0xFFcccccc)),
              SizedBox(width: 8),
              Text('Find Similar Sounds', style: TextStyle(color: Color(0xFFcccccc))),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'select_all',
          child: Row(
            children: [
              Icon(Icons.select_all, size: 18, color: Color(0xFFcccccc)),
              SizedBox(width: 8),
              Text('Select All', style: TextStyle(color: Color(0xFFcccccc))),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'zoom_selection',
          child: Row(
            children: [
              Icon(Icons.zoom_in, size: 18, color: Color(0xFFcccccc)),
              SizedBox(width: 8),
              Text('Zoom to Selection', style: TextStyle(color: Color(0xFFcccccc))),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'zoom_fit',
          child: Row(
            children: [
              Icon(Icons.fit_screen, size: 18, color: Color(0xFFcccccc)),
              SizedBox(width: 8),
              Text('Zoom to Fit', style: TextStyle(color: Color(0xFFcccccc))),
            ],
          ),
        ),
      ],
    ).then((value) {
      switch (value) {
        case 'find_similar':
          // Pass the selection range (or full duration if no selection)
          final start = widget.selectionStart;
          final end = widget.selectionEnd > widget.selectionStart
              ? widget.selectionEnd
              : widget.duration;
          widget.onFindSimilar?.call(start, end);
          break;
        case 'select_all':
          widget.onSelectionChanged?.call(0, widget.duration);
          break;
        case 'zoom_selection':
          _zoomToSelection();
          break;
        case 'zoom_fit':
          setState(() => _zoom = 1.0);
          break;
      }
    });
  }

  void _zoomToSelection() {
    if (widget.selectionEnd <= widget.selectionStart) return;
    // TODO: Implement zoom to selection
  }

  double _pixelToTime(double x) {
    final context = this.context;
    final width = (context.findRenderObject() as RenderBox?)?.size.width ?? 1;
    final visibleDuration = widget.duration / _zoom;
    return _scrollOffset + (x / width) * visibleDuration;
  }
}

class WaveformSegment {
  final double amplitude;
  final double frequency;

  WaveformSegment({required this.amplitude, required this.frequency});
}

class SpectralWaveformPainter extends CustomPainter {
  final List<WaveformSegment> segments;
  final double duration;
  final double position;
  final double selectionStart;
  final double selectionEnd;
  final double zoom;
  final double scrollOffset;

  SpectralWaveformPainter({
    required this.segments,
    required this.duration,
    required this.position,
    required this.selectionStart,
    required this.selectionEnd,
    required this.zoom,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1e1e23),
    );

    // Center line
    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      Paint()
        ..color = const Color(0xFF323237)
        ..strokeWidth = 1,
    );

    if (segments.isEmpty || duration <= 0) {
      _drawNoFileMessage(canvas, size);
      return;
    }

    // Draw selection
    if (selectionEnd > selectionStart) {
      final startX = _timeToPixel(selectionStart, size.width);
      final endX = _timeToPixel(selectionEnd, size.width);

      // Selection fill
      canvas.drawRect(
        Rect.fromLTRB(startX, 0, endX, size.height),
        Paint()..color = const Color.fromRGBO(100, 150, 255, 0.15),
      );

      // Selection borders
      final borderPaint = Paint()
        ..color = const Color.fromRGBO(100, 150, 255, 0.6)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), borderPaint);
      canvas.drawLine(Offset(endX, 0), Offset(endX, size.height), borderPaint);
    }

    // Draw waveform with frequency colors
    final visibleDuration = duration / zoom;
    final pixelsPerSegment = size.width / (segments.length / zoom);

    for (int i = 0; i < segments.length; i++) {
      final segmentTime = (i / segments.length) * duration;
      if (segmentTime < scrollOffset || segmentTime > scrollOffset + visibleDuration) continue;

      final x = _timeToPixel(segmentTime, size.width);
      final segment = segments[i];
      final barHeight = segment.amplitude * (size.height / 2 - 4);
      final color = FrequencyColors.getColorForFrequency(segment.frequency);

      // Draw bar (both above and below center)
      canvas.drawLine(
        Offset(x, centerY - barHeight),
        Offset(x, centerY + barHeight),
        Paint()
          ..color = color
          ..strokeWidth = math.max(1, pixelsPerSegment - 0.5),
      );
    }

    // Draw playhead
    final playheadX = _timeToPixel(position, size.width);
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      Paint()
        ..color = const Color(0xFFff5050)
        ..strokeWidth = 2,
    );
  }

  double _timeToPixel(double time, double width) {
    final visibleDuration = duration / zoom;
    return ((time - scrollOffset) / visibleDuration) * width;
  }

  void _drawNoFileMessage(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Drag and drop an audio file here\nor select from MyPalette',
        style: TextStyle(
          color: Color(0xFF666666),
          fontSize: 14,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: size.width);
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(SpectralWaveformPainter oldDelegate) {
    return segments != oldDelegate.segments ||
        duration != oldDelegate.duration ||
        position != oldDelegate.position ||
        selectionStart != oldDelegate.selectionStart ||
        selectionEnd != oldDelegate.selectionEnd ||
        zoom != oldDelegate.zoom ||
        scrollOffset != oldDelegate.scrollOffset;
  }
}
