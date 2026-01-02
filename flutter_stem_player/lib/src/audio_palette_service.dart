// Audio Palette Service - Sound database, fingerprinting, and similarity search
//
// This service wraps the Rust audio_palette library to provide:
// - Audio file indexing with spectral fingerprints
// - SQLite database storage
// - "Sounds-like" similarity search with segment matching
// - MIDI/CSV export of search results

import 'package:path_provider/path_provider.dart';
import 'package:flutter_stem_player/src/rust/api.dart' as rust_api;
import 'package:flutter_stem_player/src/rust/lib.dart' as rust_lib;
import 'package:flutter_stem_player/src/rust/frb_generated.dart';

/// Service for audio palette operations (database, fingerprinting, search)
class AudioPaletteService {
  static final AudioPaletteService _instance = AudioPaletteService._internal();
  factory AudioPaletteService() => _instance;
  AudioPaletteService._internal();

  bool _initialized = false;

  /// Initialize the audio palette service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize flutter_rust_bridge
    await AudioPalette.init();

    // Get the database path
    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = '${appDir.path}/audio_palette.db';

    // Initialize the database
    rust_api.initDatabase(dbPath: dbPath);

    _initialized = true;
  }

  /// Add a sound file to the palette database
  Future<int> addSound(String filepath) async {
    await _ensureInitialized();
    final id = await rust_api.addSound(filepath: filepath);
    return id.toInt();
  }

  /// Get all sounds in the database
  Future<List<rust_lib.SoundRecord>> getAllSounds() async {
    await _ensureInitialized();
    return rust_api.getAllSounds();
  }

  /// Get the total number of sounds in the database
  int getSoundCount() {
    if (!_initialized) return 0;
    return rust_api.getSoundCount().toInt();
  }

  /// Search sounds by filename
  Future<List<rust_lib.SoundRecord>> searchSounds(String query) async {
    await _ensureInitialized();
    return rust_api.searchSounds(query: query);
  }

  /// Find similar sounds to a query file
  ///
  /// [queryPath] - Path to the audio file to match
  /// [threshold] - Minimum similarity score (0-100), default 50
  /// [maxResults] - Maximum number of results, default 20
  Future<List<rust_lib.MatchResult>> findSimilar(
    String queryPath, {
    double threshold = 50.0,
    int maxResults = 20,
  }) async {
    await _ensureInitialized();
    return rust_api.findSimilar(
      queryPath: queryPath,
      threshold: threshold,
      maxResults: BigInt.from(maxResults),
    );
  }

  /// Find similar sounds with exact segment matching
  ///
  /// Returns precise time ranges where matches occur in each file.
  /// Use this for detailed analysis of where the similarity is.
  Future<List<rust_lib.MatchResult>> findSimilarWithSegments(
    String queryPath, {
    double threshold = 50.0,
    int maxResults = 20,
  }) async {
    await _ensureInitialized();
    return rust_api.findSimilarWithSegments(
      queryPath: queryPath,
      threshold: threshold,
      maxResults: BigInt.from(maxResults),
    );
  }

  /// Find similar sounds from raw audio samples
  ///
  /// Use this for searching from a selected region of audio.
  /// [samples] - Audio samples (mono, float32)
  /// [sampleRate] - Sample rate of the audio
  Future<List<rust_lib.MatchResult>> findSimilarFromSamples(
    List<double> samples,
    int sampleRate, {
    double threshold = 50.0,
    int maxResults = 20,
  }) async {
    await _ensureInitialized();
    return rust_api.findSimilarFromSamples(
      samples: samples,
      sampleRate: sampleRate,
      threshold: threshold,
      maxResults: BigInt.from(maxResults),
    );
  }

  /// Export match results to MIDI file
  ///
  /// Creates a MIDI file where each match is a note at the matching timestamp.
  Future<void> exportToMidi(
    List<rust_lib.MatchResult> matches,
    String outputPath, {
    int tempoBpm = 120,
    int baseNote = 60,
  }) async {
    await _ensureInitialized();
    await rust_api.exportToMidi(
      matches: matches,
      outputPath: outputPath,
      tempoBpm: tempoBpm,
      baseNote: baseNote,
    );
  }

  /// Export match results to CSV file
  Future<void> exportToCsv(
    List<rust_lib.MatchResult> matches,
    String outputPath,
  ) async {
    await _ensureInitialized();
    await rust_api.exportToCsv(matches: matches, outputPath: outputPath);
  }

  /// Export match results to markers file
  Future<void> exportToMarkers(
    List<rust_lib.MatchResult> matches,
    String outputPath,
  ) async {
    await _ensureInitialized();
    await rust_api.exportToMarkers(matches: matches, outputPath: outputPath);
  }

  /// Remove a sound from the database
  Future<void> removeSound(int soundId) async {
    await _ensureInitialized();
    await rust_api.removeSound(soundId: soundId);
  }

  /// Get fingerprint info for a sound file
  Future<rust_api.AudioFingerprintInfo> getFingerprint(String filepath) async {
    await _ensureInitialized();
    return rust_api.getFingerprint(filepath: filepath);
  }

  /// Compute similarity between two audio files
  double computeSimilarity(String file1, String file2) {
    if (!_initialized) return 0.0;
    return rust_api.computeSimilarity(fp1Path: file1, fp2Path: file2);
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}
