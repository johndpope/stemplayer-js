// AudioFileView - Main layout matching FSPalette/AudioFileView Python app
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'audio_player_service.dart';
import 'catalog_view.dart';
import 'search_view.dart';
import 'spectral_waveform_view.dart';
import 'transport_bar.dart';
import 'info_panel.dart';
import 'frequency_legend.dart';
import 'toast_notification.dart';

class AudioFileView extends StatefulWidget {
  const AudioFileView({super.key});

  @override
  State<AudioFileView> createState() => _AudioFileViewState();
}

class _AudioFileViewState extends State<AudioFileView> {
  // Focus node for keyboard shortcuts
  final FocusNode _focusNode = FocusNode();

  // Audio player
  final AudioPlayerService _audioPlayer = AudioPlayerService();
  StreamSubscription<double>? _positionSubscription;
  StreamSubscription<AudioPlaybackState>? _stateSubscription;

  // Splitter position
  double _sidebarWidth = 350;
  static const double _minSidebarWidth = 250;
  static const double _maxSidebarWidth = 500;

  // Current file
  String? _currentFilePath;
  String? _currentFileName;
  double _duration = 0;
  double _position = 0;
  double _sampleRate = 44100;
  int _channels = 2;
  String _format = '';

  // Selection
  double _selectionStart = 0;
  double _selectionEnd = 0;

  // Playback state
  bool _isPlaying = false;
  bool _isLooping = false;

  // Toast
  final GlobalKey<ToastNotificationState> _toastKey = GlobalKey();

  // Drag state
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    // Request focus after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _initAudioPlayer() async {
    await _audioPlayer.init();

    // Listen to position updates
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });

    // Listen to state changes
    _stateSubscription = _audioPlayer.stateStream.listen((state) {
      setState(() {
        _isPlaying = state == AudioPlaybackState.playing;
      });
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _audioPlayer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Playback controls
        const SingleActivator(LogicalKeyboardKey.space): _togglePlayPause,
        const SingleActivator(LogicalKeyboardKey.enter): _onPlay,
        const SingleActivator(LogicalKeyboardKey.escape): _onStop,
        const SingleActivator(LogicalKeyboardKey.keyL): _onLoopToggle,

        // Navigation
        const SingleActivator(LogicalKeyboardKey.home): () => _onSeek(0),
        const SingleActivator(LogicalKeyboardKey.end): () => _onSeek(_duration),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _onSeek((_position - 1).clamp(0, _duration)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _onSeek((_position + 1).clamp(0, _duration)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () => _onSeek((_position - 5).clamp(0, _duration)),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () => _onSeek((_position + 5).clamp(0, _duration)),

        // Zoom
        const SingleActivator(LogicalKeyboardKey.equal, meta: true): _onZoomIn,
        const SingleActivator(LogicalKeyboardKey.minus, meta: true): _onZoomOut,
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true): _onZoomFit,

        // Selection
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () => _onSelectionChanged(0, _duration),
      },
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: Scaffold(
          backgroundColor: const Color(0xFF1e1e1e),
          body: Column(
            children: [
              // Main content area
              Expanded(
                child: Row(
                  children: [
                    // Left sidebar with tabs
                    _buildSidebar(),
                    // Resizable divider
                    _buildDivider(),
                    // Right panel - audio editor
                    Expanded(child: _buildEditorPanel()),
                  ],
                ),
              ),
              // Toast notification overlay
              ToastNotification(key: _toastKey),
            ],
          ),
        ),
        ),
      ),
    );
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _onPause();
    } else {
      _onPlay();
    }
  }

  Widget _buildSidebar() {
    return Container(
      width: _sidebarWidth,
      color: const Color(0xFF252525),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // Tab bar
            Container(
              color: const Color(0xFF2d2d2d),
              child: const TabBar(
                tabs: [
                  Tab(text: 'MyPalette'),
                  Tab(text: 'Search'),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xFF888888),
                indicatorColor: Color(0xFF4a9eff),
                dividerColor: Color(0xFF333333),
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  CatalogView(
                    onSoundSelected: _onSoundSelected,
                    onIndexingStarted: _onIndexingStarted,
                    onIndexingProgress: _onIndexingProgress,
                    onIndexingComplete: _onIndexingComplete,
                  ),
                  SearchView(
                    onResultSelected: _onSearchResultSelected,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            _sidebarWidth = (_sidebarWidth + details.delta.dx)
                .clamp(_minSidebarWidth, _maxSidebarWidth);
          });
        },
        child: Container(
          width: 4,
          color: const Color(0xFF333333),
          child: const Center(
            child: Icon(
              Icons.drag_indicator,
              size: 12,
              color: Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorPanel() {
    return DropTarget(
      onDragEntered: (details) {
        debugPrint('Drag entered');
        setState(() => _isDragging = true);
      },
      onDragExited: (details) {
        debugPrint('Drag exited');
        setState(() => _isDragging = false);
      },
      onDragDone: (details) {
        debugPrint('Drag done: ${details.files.length} files');
        for (final file in details.files) {
          debugPrint('  File: ${file.path}');
        }
        setState(() => _isDragging = false);
        _handleDroppedFiles(details);
      },
      child: Stack(
        children: [
          Container(
            color: const Color(0xFF1e1e23),
            child: Column(
              children: [
                // Info panel
                InfoPanel(
                  fileName: _currentFileName,
                  format: _format,
                  sampleRate: _sampleRate,
                  channels: _channels,
                  duration: _duration,
                ),
                // Frequency legend
                const FrequencyLegend(),
                // Spectral waveform view
                Expanded(
                  child: SpectralWaveformView(
                    filePath: _currentFilePath,
                    duration: _duration,
                    position: _position,
                    selectionStart: _selectionStart,
                    selectionEnd: _selectionEnd,
                    onSelectionChanged: _onSelectionChanged,
                    onPositionTap: _onPositionTap,
                    onFindSimilar: _onFindSimilar,
                  ),
                ),
                // Transport bar
                TransportBar(
                  position: _position,
                  duration: _duration,
                  isPlaying: _isPlaying,
                  isLooping: _isLooping,
                  onPlay: _onPlay,
                  onPause: _onPause,
                  onStop: _onStop,
                  onSeek: _onSeek,
                  onLoopToggle: _onLoopToggle,
                  onZoomIn: _onZoomIn,
                  onZoomOut: _onZoomOut,
                  onZoomFit: _onZoomFit,
                ),
              ],
            ),
          ),
          // Drag overlay
          if (_isDragging)
            Container(
              color: const Color(0xFF4a9eff).withValues(alpha: 0.2),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2d2d2d),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4a9eff),
                      width: 2,
                    ),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.audio_file,
                        size: 48,
                        color: Color(0xFF4a9eff),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Drop audio file here',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleDroppedFiles(DropDoneDetails details) {
    if (details.files.isEmpty) return;

    // Get the first audio file
    final audioExtensions = ['wav', 'mp3', 'aiff', 'flac', 'ogg', 'm4a'];
    for (final file in details.files) {
      final path = file.path;
      final ext = path.split('.').last.toLowerCase();
      if (audioExtensions.contains(ext)) {
        _loadAudioFile(path);
        return;
      }
    }
  }

  Future<void> _loadAudioFile(String filePath) async {
    debugPrint('Loading audio file: $filePath');
    // Stop any current playback
    await _audioPlayer.stop();

    final success = await _audioPlayer.loadFile(filePath);
    debugPrint('Load result: $success');
    if (success) {
      setState(() {
        _currentFilePath = filePath;
        _currentFileName = filePath.split('/').last;
        _position = 0;
        _selectionStart = 0;
        _selectionEnd = 0;
        _duration = _audioPlayer.duration;
        _sampleRate = _audioPlayer.sampleRate.toDouble();
        _channels = _audioPlayer.channels;
        _format = _audioPlayer.format;
      });
    }
  }

  // Callbacks
  void _onSoundSelected(String filePath, String fileName) {
    _loadAudioFile(filePath);
  }

  Future<void> _onSearchResultSelected(String filePath, double matchStart, double matchEnd) async {
    await _loadAudioFile(filePath);
    setState(() {
      _selectionStart = matchStart;
      _selectionEnd = matchEnd;
      _position = matchStart;
    });
    _audioPlayer.seek(matchStart);
  }

  void _onSelectionChanged(double start, double end) {
    setState(() {
      _selectionStart = start;
      _selectionEnd = end;
    });
  }

  void _onPositionTap(double position) {
    _audioPlayer.seek(position);
    setState(() {
      _position = position;
    });
  }

  void _onFindSimilar(double selectionStart, double selectionEnd) {
    // Switch to search tab and trigger similarity search with selection
    DefaultTabController.of(context).animateTo(1);

    // Show toast with selection info
    final duration = selectionEnd - selectionStart;
    _toastKey.currentState?.show(
      message: 'Finding similar sounds (${duration.toStringAsFixed(2)}s snippet)',
      showProgress: true,
      autoHide: true,
    );

    // TODO: Trigger actual similarity search with the selection range
    // This would extract audio fingerprint from the selected range
    // and search the database for similar sounds
  }

  void _onPlay() {
    _audioPlayer.play();
  }

  void _onPause() {
    _audioPlayer.pause();
  }

  void _onStop() {
    _audioPlayer.stop();
  }

  void _onSeek(double position) {
    _audioPlayer.seek(position);
    setState(() => _position = position);
  }

  void _onLoopToggle() {
    setState(() => _isLooping = !_isLooping);
    _audioPlayer.setLoop(_isLooping);
  }

  void _onZoomIn() {
    // TODO: Zoom in waveform
  }

  void _onZoomOut() {
    // TODO: Zoom out waveform
  }

  void _onZoomFit() {
    // TODO: Fit waveform to view
  }

  void _onIndexingStarted(String message) {
    _toastKey.currentState?.show(
      message: message,
      showProgress: true,
      autoHide: false,
    );
  }

  void _onIndexingProgress(int current, int total, String fileName) {
    _toastKey.currentState?.updateProgress(
      current: current,
      total: total,
      detail: fileName,
    );
  }

  void _onIndexingComplete(int count) {
    _toastKey.currentState?.show(
      message: 'Indexing complete: $count files added',
      showProgress: false,
      autoHide: true,
    );
  }
}
