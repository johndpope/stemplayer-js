/// Flutter Stem Player - A multi-track audio player with frequency visualization
///
/// Ported from stemplayer-js with flutter_soloud for audio playback
library flutter_stem_player;

// Models
export 'src/models/stem.dart';

// Services
export 'src/services/audio_service.dart';
export 'src/services/stem_player_controller.dart';
export 'src/audio_palette_service.dart';

// Widgets
export 'src/widgets/stem_player.dart';
export 'src/widgets/stem_row.dart';
export 'src/widgets/waveform_widget.dart';
export 'src/widgets/player_controls.dart';

// Painters
export 'src/painters/waveform_painter.dart';

// Utils
export 'src/utils/fft.dart';

// Rust FFI (Audio Palette)
export 'src/rust/api.dart';
export 'src/rust/lib.dart';
