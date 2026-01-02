import 'package:flutter/material.dart';

import '../models/stem.dart';
import '../utils/fft.dart';
import 'waveform_widget.dart';

/// A single stem row with label, controls, and waveform
class StemRow extends StatelessWidget {
  final Stem stem;
  final WaveformData? waveform;
  final List<FrequencySegment>? frequencySegments;
  final double progress;
  final bool showFrequencyColors;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onSoloToggle;
  final ValueChanged<double>? onVolumeChanged;
  final ValueChanged<double>? onSeek;
  final bool isCompact;

  const StemRow({
    super.key,
    required this.stem,
    this.waveform,
    this.frequencySegments,
    this.progress = 0,
    this.showFrequencyColors = true,
    this.onMuteToggle,
    this.onSoloToggle,
    this.onVolumeChanged,
    this.onSeek,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSolo = stem.solo;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 16,
        vertical: isCompact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: isCompact ? _buildCompactLayout(context) : _buildFullLayout(context),
    );
  }

  Widget _buildFullLayout(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Label and controls
        SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stem.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildControlButton(
                    context,
                    icon: stem.muted ? Icons.volume_off : Icons.volume_up,
                    isActive: stem.muted,
                    onPressed: onMuteToggle,
                    tooltip: stem.muted ? 'Unmute' : 'Mute',
                  ),
                  const SizedBox(width: 4),
                  _buildControlButton(
                    context,
                    icon: Icons.headphones,
                    isActive: stem.solo,
                    activeColor: Colors.amber,
                    onPressed: onSoloToggle,
                    tooltip: stem.solo ? 'Unsolo' : 'Solo',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildVolumeSlider(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Waveform
        Expanded(
          child: waveform != null
              ? WaveformWidget(
                  bars: waveform!.getBars(),
                  frequencySegments: frequencySegments,
                  progress: progress,
                  scaleY: stem.effectiveVolume,
                  showFrequencyColors: showFrequencyColors,
                  onSeek: onSeek,
                  height: 50,
                )
              : const WaveformPlaceholder(height: 50),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stem.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildControlButton(
              context,
              icon: stem.muted ? Icons.volume_off : Icons.volume_up,
              isActive: stem.muted,
              onPressed: onMuteToggle,
              tooltip: stem.muted ? 'Unmute' : 'Mute',
              size: 20,
            ),
            _buildControlButton(
              context,
              icon: Icons.headphones,
              isActive: stem.solo,
              activeColor: Colors.amber,
              onPressed: onSoloToggle,
              tooltip: stem.solo ? 'Unsolo' : 'Solo',
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 4),
        waveform != null
            ? WaveformWidget(
                bars: waveform!.getBars(),
                frequencySegments: frequencySegments,
                progress: progress,
                scaleY: stem.effectiveVolume,
                showFrequencyColors: showFrequencyColors,
                onSeek: onSeek,
                height: 40,
              )
            : const WaveformPlaceholder(height: 40),
      ],
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required bool isActive,
    Color? activeColor,
    VoidCallback? onPressed,
    String? tooltip,
    double size = 24,
  }) {
    final color = isActive
        ? (activeColor ?? Theme.of(context).colorScheme.primary)
        : Theme.of(context).iconTheme.color?.withOpacity(0.5);

    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: size,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeSlider(BuildContext context) {
    return SizedBox(
      height: 20,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        ),
        child: Slider(
          value: stem.volume,
          onChanged: stem.muted ? null : onVolumeChanged,
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
    );
  }
}

/// Collapsed stem row showing just the label
class CollapsedStemRow extends StatelessWidget {
  final Stem stem;
  final VoidCallback? onExpand;

  const CollapsedStemRow({
    super.key,
    required this.stem,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onExpand,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text(
              stem.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            if (stem.muted)
              const Icon(Icons.volume_off, size: 16),
            if (stem.solo)
              const Icon(Icons.headphones, size: 16, color: Colors.amber),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more, size: 16),
          ],
        ),
      ),
    );
  }
}
