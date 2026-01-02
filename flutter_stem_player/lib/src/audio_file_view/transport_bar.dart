// TransportBar - Playback controls matching AudioFileView Python app
import 'package:flutter/material.dart';

class TransportBar extends StatelessWidget {
  final double position;
  final double duration;
  final bool isPlaying;
  final bool isLooping;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onStop;
  final ValueChanged<double>? onSeek;
  final VoidCallback? onLoopToggle;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomFit;

  const TransportBar({
    super.key,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isLooping,
    this.onPlay,
    this.onPause,
    this.onStop,
    this.onSeek,
    this.onLoopToggle,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomFit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF2d2d2d),
        border: Border(
          top: BorderSide(color: Color(0xFF444444), width: 1),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          // Transport buttons
          _TransportButton(
            icon: Icons.skip_previous,
            onPressed: () => onSeek?.call(0),
            tooltip: 'Rewind',
          ),
          _TransportButton(
            icon: isPlaying ? Icons.pause : Icons.play_arrow,
            onPressed: isPlaying ? onPause : onPlay,
            tooltip: isPlaying ? 'Pause' : 'Play',
            highlighted: isPlaying,
          ),
          _TransportButton(
            icon: Icons.stop,
            onPressed: onStop,
            tooltip: 'Stop',
          ),
          _TransportButton(
            icon: Icons.repeat,
            onPressed: onLoopToggle,
            tooltip: 'Loop',
            highlighted: isLooping,
          ),
          const SizedBox(width: 16),
          // Time display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1e1e1e),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF444444)),
            ),
            child: Text(
              '${_formatTime(position)} / ${_formatTime(duration)}',
              style: const TextStyle(
                color: Color(0xFFcccccc),
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          const Spacer(),
          // Zoom controls
          _TransportButton(
            icon: Icons.remove,
            onPressed: onZoomOut,
            tooltip: 'Zoom Out',
            small: true,
          ),
          _TransportButton(
            icon: Icons.add,
            onPressed: onZoomIn,
            tooltip: 'Zoom In',
            small: true,
          ),
          _TransportButton(
            icon: Icons.fit_screen,
            onPressed: onZoomFit,
            tooltip: 'Fit to View',
            small: true,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return '00:00.000';
    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toStringAsFixed(3).padLeft(6, '0')}';
  }
}

class _TransportButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool highlighted;
  final bool small;

  const _TransportButton({
    required this.icon,
    this.onPressed,
    required this.tooltip,
    this.highlighted = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 28.0 : 36.0;
    final iconSize = small ? 18.0 : 22.0;

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: highlighted ? const Color(0xFF3d5a80) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(4),
            hoverColor: const Color(0xFF3a3a3a),
            child: Icon(
              icon,
              size: iconSize,
              color: highlighted ? Colors.white : const Color(0xFFaaaaaa),
            ),
          ),
        ),
      ),
    );
  }
}
