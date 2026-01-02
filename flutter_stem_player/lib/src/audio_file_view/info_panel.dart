// InfoPanel - Audio file metadata display matching AudioFileView Python app
import 'package:flutter/material.dart';

class InfoPanel extends StatelessWidget {
  final String? fileName;
  final String format;
  final double sampleRate;
  final int channels;
  final double duration;

  const InfoPanel({
    super.key,
    this.fileName,
    this.format = '',
    this.sampleRate = 0,
    this.channels = 0,
    this.duration = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF2d2d2d),
        border: Border(
          bottom: BorderSide(color: Color(0xFF444444), width: 1),
        ),
      ),
      child: Row(
        children: [
          // File icon and name
          const Icon(
            Icons.audio_file,
            color: Color(0xFF888888),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName ?? 'No file loaded',
              style: TextStyle(
                color: fileName != null ? Colors.white : const Color(0xFF666666),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (fileName != null) ...[
            const SizedBox(width: 16),
            _InfoChip(label: 'Format', value: format.toUpperCase()),
            const SizedBox(width: 12),
            _InfoChip(label: 'Rate', value: '${(sampleRate / 1000).toStringAsFixed(1)}kHz'),
            const SizedBox(width: 12),
            _InfoChip(label: 'Ch', value: channels == 1 ? 'Mono' : 'Stereo'),
            const SizedBox(width: 12),
            _InfoChip(label: 'Length', value: _formatDuration(duration)),
          ],
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    if (seconds <= 0) return '0:00';
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    final ms = ((seconds % 1) * 1000).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFcccccc),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
