import 'package:flutter/material.dart';

/// Main player controls (play/pause, progress, time, etc.)
class PlayerControls extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final bool loop;
  final bool showFrequencyColors;
  final double progress;
  final double currentTime;
  final double duration;
  final double zoom;
  final VoidCallback? onPlayPause;
  final VoidCallback? onStop;
  final VoidCallback? onLoopToggle;
  final VoidCallback? onFrequencyColorsToggle;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final ValueChanged<double>? onSeek;
  final String Function(double)? formatTime;
  final bool isCompact;

  const PlayerControls({
    super.key,
    this.isPlaying = false,
    this.isLoading = false,
    this.loop = false,
    this.showFrequencyColors = true,
    this.progress = 0,
    this.currentTime = 0,
    this.duration = 0,
    this.zoom = 1.0,
    this.onPlayPause,
    this.onStop,
    this.onLoopToggle,
    this.onFrequencyColorsToggle,
    this.onZoomIn,
    this.onZoomOut,
    this.onSeek,
    this.formatTime,
    this.isCompact = false,
  });

  String _formatTime(double seconds) {
    if (formatTime != null) return formatTime!(seconds);

    final duration = Duration(milliseconds: (seconds * 1000).round());
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return isCompact ? _buildCompactControls(context) : _buildFullControls(context);
  }

  Widget _buildFullControls(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          Row(
            children: [
              Text(
                _formatTime(currentTime),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: onSeek,
                    activeColor: theme.colorScheme.primary,
                    inactiveColor: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatTime(duration),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Loop button
              _ControlButton(
                icon: Icons.repeat,
                isActive: loop,
                onPressed: onLoopToggle,
                tooltip: 'Loop',
              ),
              const SizedBox(width: 8),
              // Stop button
              _ControlButton(
                icon: Icons.stop,
                onPressed: onStop,
                tooltip: 'Stop',
              ),
              const SizedBox(width: 8),
              // Play/Pause button
              _PlayButton(
                isPlaying: isPlaying,
                isLoading: isLoading,
                onPressed: onPlayPause,
              ),
              const SizedBox(width: 8),
              // Frequency colors toggle
              _ControlButton(
                icon: Icons.color_lens,
                isActive: showFrequencyColors,
                onPressed: onFrequencyColorsToggle,
                tooltip: 'Frequency colors',
              ),
              const SizedBox(width: 8),
              // Zoom controls
              _ControlButton(
                icon: Icons.zoom_out,
                onPressed: zoom > 1 ? onZoomOut : null,
                tooltip: 'Zoom out',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${zoom.toStringAsFixed(1)}x',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              _ControlButton(
                icon: Icons.zoom_in,
                onPressed: zoom < 10 ? onZoomIn : null,
                tooltip: 'Zoom in',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactControls(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Play/Pause
          _PlayButton(
            isPlaying: isPlaying,
            isLoading: isLoading,
            onPressed: onPlayPause,
            size: 36,
          ),
          const SizedBox(width: 8),
          // Time
          Text(
            _formatTime(currentTime),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          // Progress
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: onSeek,
                activeColor: theme.colorScheme.primary,
                inactiveColor: theme.colorScheme.primary.withOpacity(0.2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(duration),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          // Loop
          _ControlButton(
            icon: Icons.repeat,
            isActive: loop,
            onPressed: onLoopToggle,
            tooltip: 'Loop',
            size: 20,
          ),
        ],
      ),
    );
  }
}

/// Individual control button
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  const _ControlButton({
    required this.icon,
    this.isActive = false,
    this.onPressed,
    this.tooltip,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = onPressed == null
        ? theme.disabledColor
        : isActive
            ? theme.colorScheme.primary
            : theme.iconTheme.color;

    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}

/// Play/Pause button with loading state
class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onPressed;
  final double size;

  const _PlayButton({
    this.isPlaying = false,
    this.isLoading = false,
    this.onPressed,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: size * 0.5,
                    height: size * 0.5,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: size * 0.6,
                    color: theme.colorScheme.onPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Mini controls for inline use
class MiniControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onStop;

  const MiniControls({
    super.key,
    this.isPlaying = false,
    this.onPlayPause,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.stop),
          onPressed: onStop,
          iconSize: 20,
        ),
        IconButton(
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: onPlayPause,
          iconSize: 24,
        ),
      ],
    );
  }
}
