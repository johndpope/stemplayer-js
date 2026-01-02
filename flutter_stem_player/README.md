# Flutter Stem Player

A Flutter port of [stemplayer-js](https://github.com/firstcoders/stemplayer-js-monorepo) with flutter_soloud for audio playback and frequency-colored waveform visualization.

## Features

- **Multi-stem Audio Playback** - Play multiple audio stems (Drums, Bass, Vocals, etc.) in sync
- **FFT Frequency Analysis** - Real-time Fast Fourier Transform for frequency detection
- **Comparisonics-style Waveform Coloring** - Color waveforms based on dominant frequencies:
  - Sub-bass (50-100 Hz): Dark purple
  - Bass (100-400 Hz): Blue-purple
  - Low-mid (400-800 Hz): Teal
  - Mid (800-1500 Hz): Teal-green
  - Mid (1500-3000 Hz): Green
  - Upper-mid (3000-6000 Hz): Yellow-orange
  - Presence (6000-10000 Hz): Orange-red
  - Air (10000+ Hz): Pink-magenta
- **Per-stem Controls** - Volume, mute, and solo for each stem
- **Responsive Design** - Adapts to different screen sizes
- **Interactive Waveforms** - Click/tap to seek
- **Loop & Zoom** - Loop playback and zoom waveforms

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_stem_player:
    path: ./flutter_stem_player  # or your path
```

Or add from Git:

```yaml
dependencies:
  flutter_stem_player:
    git:
      url: https://github.com/your-repo/stemplayer-js.git
      path: flutter_stem_player
```

## Quick Start

```dart
import 'package:flutter_stem_player/flutter_stem_player.dart';

StemPlayer(
  stems: [
    Stem(
      id: 'drums',
      label: 'Drums',
      audioUrl: 'assets/audio/drums.mp3',
    ),
    Stem(
      id: 'bass',
      label: 'Bass',
      audioUrl: 'assets/audio/bass.mp3',
    ),
    Stem(
      id: 'vocals',
      label: 'Vocals',
      audioUrl: 'assets/audio/vocals.mp3',
    ),
  ],
  autoplay: false,
  loop: false,
)
```

## Using the Controller

For more control, use `StemPlayerController`:

```dart
class MyPlayerPage extends StatefulWidget {
  @override
  State<MyPlayerPage> createState() => _MyPlayerPageState();
}

class _MyPlayerPageState extends State<MyPlayerPage> {
  late final StemPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = StemPlayerController();
    _setup();
  }

  Future<void> _setup() async {
    await _controller.init();

    await _controller.addStem(Stem(
      id: 'drums',
      label: 'Drums',
      audioUrl: 'assets/audio/drums.mp3',
    ));

    // Add more stems...
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StemPlayerWithController(
      controller: _controller,
    );
  }
}
```

## Custom Waveform Widgets

Use individual waveform widgets for custom UIs:

```dart
// Frequency-colored waveform
WaveformWidget(
  bars: waveformBars,
  frequencySegments: frequencyData,
  progress: 0.5,
  showFrequencyColors: true,
  onSeek: (progress) => controller.seek(progress),
)

// Mirror waveform
MirrorWaveformWidget(
  bars: waveformBars,
  frequencySegments: frequencyData,
  progress: 0.5,
)

// Simple waveform
SimpleWaveformWidget(
  bars: waveformBars,
  progress: 0.5,
  waveformColor: Colors.grey,
  progressColor: Colors.purple,
)
```

## Waveform Data

Waveform data can be provided as JSON (compatible with BBC's audiowaveform format):

```json
{
  "sample_rate": 44100,
  "samples_per_pixel": 256,
  "channels": 1,
  "data": [-0.5, 0.5, -0.3, 0.4, ...]
}
```

Or generate it programmatically:

```dart
final bars = List.generate(200, (i) {
  final amplitude = /* your audio analysis */;
  return WaveformBar(min: -amplitude, max: amplitude);
});
```

## API Reference

### Stem

```dart
Stem(
  id: 'unique-id',           // Required: Unique identifier
  label: 'Drums',            // Required: Display label
  audioUrl: 'path/to/file',  // Required: Audio file path or URL
  waveformUrl: 'path.json',  // Optional: Pre-computed waveform JSON
  volume: 1.0,               // Optional: Initial volume (0-1)
  muted: false,              // Optional: Initial mute state
  solo: false,               // Optional: Initial solo state
)
```

### StemPlayerController

```dart
// Initialization
await controller.init();

// Playback
await controller.play();
controller.pause();
await controller.stop();
await controller.togglePlayPause();

// Seeking
controller.seek(0.5); // Progress (0-1)
controller.seek(30.0, isProgress: false); // Seconds

// Stem control
controller.setStemVolume('drums', 0.8);
controller.toggleStemMute('drums');
controller.toggleStemSolo('drums');

// Other
controller.setZoom(2.0);
controller.zoomIn();
controller.zoomOut();
controller.toggleLoop();
controller.toggleFrequencyColors();

// State
controller.isPlaying;
controller.currentPosition;
controller.duration;
controller.progress;
controller.stems;
```

## Dependencies

- [flutter_soloud](https://pub.dev/packages/flutter_soloud) - Cross-platform audio playback
- [provider](https://pub.dev/packages/provider) - State management
- [http](https://pub.dev/packages/http) - Network requests

## Platform Support

| Platform | Support |
|----------|---------|
| Android  | ✅      |
| iOS      | ✅      |
| macOS    | ✅      |
| Windows  | ✅      |
| Linux    | ✅      |
| Web      | ⚠️ Partial (flutter_soloud limitation) |

## License

MIT License - See LICENSE file for details.

## Credits

- Original JavaScript implementation: [stemplayer-js](https://github.com/firstcoders/stemplayer-js-monorepo)
- Audio engine: [SoLoud](https://solhsa.com/soloud/) via flutter_soloud
