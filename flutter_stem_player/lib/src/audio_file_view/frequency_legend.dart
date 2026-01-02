// FrequencyLegend - Color reference for frequency bands matching AudioFileView Python app
import 'package:flutter/material.dart';

// Frequency band colors matching the Python implementation
class FrequencyColors {
  static const Color bass = Color.fromRGBO(138, 100, 168, 1);      // < 150Hz - Purple
  static const Color low = Color.fromRGBO(80, 180, 190, 1);        // 150-400Hz - Cyan
  static const Color mid = Color.fromRGBO(120, 190, 90, 1);        // 400-1000Hz - Green
  static const Color upper = Color.fromRGBO(220, 200, 80, 1);      // 1000-2500Hz - Yellow
  static const Color presence = Color.fromRGBO(230, 150, 80, 1);   // 2500-5000Hz - Orange
  static const Color high = Color.fromRGBO(220, 120, 150, 1);      // 5000-10000Hz - Pink
  static const Color veryHigh = Color.fromRGBO(200, 130, 200, 1);  // > 10000Hz - Magenta

  static const List<FrequencyBand> bands = [
    FrequencyBand('Bass', '<150Hz', bass),
    FrequencyBand('Low', '150-400Hz', low),
    FrequencyBand('Mid', '400-1kHz', mid),
    FrequencyBand('Upper', '1-2.5kHz', upper),
    FrequencyBand('Presence', '2.5-5kHz', presence),
    FrequencyBand('High', '5-10kHz', high),
    FrequencyBand('V.High', '>10kHz', veryHigh),
  ];

  /// Get color for a frequency in Hz
  static Color getColorForFrequency(double frequency) {
    if (frequency < 150) return bass;
    if (frequency < 400) return low;
    if (frequency < 1000) return mid;
    if (frequency < 2500) return upper;
    if (frequency < 5000) return presence;
    if (frequency < 10000) return high;
    return veryHigh;
  }

  /// Get band index for a frequency in Hz (0-6)
  static int getBandIndex(double frequency) {
    if (frequency < 150) return 0;
    if (frequency < 400) return 1;
    if (frequency < 1000) return 2;
    if (frequency < 2500) return 3;
    if (frequency < 5000) return 4;
    if (frequency < 10000) return 5;
    return 6;
  }
}

class FrequencyBand {
  final String name;
  final String range;
  final Color color;

  const FrequencyBand(this.name, this.range, this.color);
}

class FrequencyLegend extends StatelessWidget {
  const FrequencyLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF252525),
        border: Border(
          bottom: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: FrequencyColors.bands.map((band) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: band.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    band.name,
                    style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
