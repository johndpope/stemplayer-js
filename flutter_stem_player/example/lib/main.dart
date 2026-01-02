import 'package:flutter/material.dart';
import 'package:flutter_stem_player/flutter_stem_player.dart';

/// Example showing how to use the Flutter Stem Player with real audio files
void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stem Player Example',
      theme: ThemeData.dark(useMaterial3: true),
      home: const ExamplePage(),
    );
  }
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stem Player Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StemPlayer(
          // Replace these with your actual audio file paths or URLs
          stems: [
            Stem(
              id: 'drums',
              label: 'Drums',
              // Local asset
              audioUrl: 'assets/audio/drums.mp3',
              // Optional: pre-computed waveform JSON
              waveformUrl: 'assets/waveforms/drums.json',
            ),
            Stem(
              id: 'bass',
              label: 'Bass',
              // Or use a URL
              audioUrl: 'https://example.com/stems/bass.mp3',
            ),
            Stem(
              id: 'vocals',
              label: 'Vocals',
              audioUrl: 'assets/audio/vocals.mp3',
              volume: 0.8, // Start at 80% volume
            ),
            Stem(
              id: 'other',
              label: 'Other',
              audioUrl: 'assets/audio/other.mp3',
            ),
          ],
          autoplay: false,
          loop: false,
          showMasterWaveform: true,
          onEnd: () {
            debugPrint('Playback finished!');
          },
        ),
      ),
    );
  }
}

/// Example using the controller directly for more control
class ControllerExamplePage extends StatefulWidget {
  const ControllerExamplePage({super.key});

  @override
  State<ControllerExamplePage> createState() => _ControllerExamplePageState();
}

class _ControllerExamplePageState extends State<ControllerExamplePage> {
  late final StemPlayerController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _controller = StemPlayerController();
    _setup();
  }

  Future<void> _setup() async {
    await _controller.init();

    // Add stems one by one
    await _controller.addStem(Stem(
      id: 'drums',
      label: 'Drums',
      audioUrl: 'assets/audio/drums.mp3',
    ));

    await _controller.addStem(Stem(
      id: 'bass',
      label: 'Bass',
      audioUrl: 'assets/audio/bass.mp3',
    ));

    setState(() => _isReady = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Use the controller with the widget
        Expanded(
          child: StemPlayerWithController(
            controller: _controller,
          ),
        ),

        // Or build custom UI using the controller
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _controller.togglePlayPause,
                child: Text(_controller.isPlaying ? 'Pause' : 'Play'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => _controller.seek(0.5), // Seek to 50%
                child: const Text('Seek to 50%'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => _controller.toggleStemSolo('drums'),
                child: const Text('Solo Drums'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Example with custom waveform styling
class CustomStyleExamplePage extends StatelessWidget {
  const CustomStyleExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Create custom waveform data
    final bars = List.generate(150, (i) {
      final progress = i / 150;
      final amplitude = 0.3 + 0.4 * (progress * 10).sin().abs();
      return WaveformBar(min: -amplitude, max: amplitude);
    });

    // Create frequency segments for coloring
    final frequencies = List.generate(150, (i) {
      final freq = 100 + (i / 150) * 10000; // 100Hz to 10kHz
      return FrequencySegment(
        dominantFrequency: freq,
        magnitude: bars[i].height,
        lowEnergy: freq < 400 ? 0.7 : 0.2,
        midEnergy: freq >= 400 && freq < 4000 ? 0.7 : 0.2,
        highEnergy: freq >= 4000 ? 0.7 : 0.2,
        color: FrequencyBands.getColorForFrequency(freq),
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Custom Waveform Styles')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Bar Waveform with Frequency Colors'),
            const SizedBox(height: 8),
            WaveformWidget(
              bars: bars,
              frequencySegments: frequencies,
              progress: 0.4,
              showFrequencyColors: true,
              height: 80,
            ),

            const SizedBox(height: 24),

            const Text('Mirror Waveform'),
            const SizedBox(height: 8),
            MirrorWaveformWidget(
              bars: bars,
              frequencySegments: frequencies,
              progress: 0.4,
              showFrequencyColors: true,
              height: 100,
            ),

            const SizedBox(height: 24),

            const Text('Simple Waveform (No Frequency Colors)'),
            const SizedBox(height: 8),
            SimpleWaveformWidget(
              bars: bars,
              progress: 0.4,
              waveformColor: Colors.grey.shade700,
              progressColor: Colors.purple,
              height: 60,
            ),
          ],
        ),
      ),
    );
  }
}

// Math extension
extension on double {
  double sin() => _sin(this);
}

import 'dart:math' as math;
double _sin(double x) => math.sin(x);
