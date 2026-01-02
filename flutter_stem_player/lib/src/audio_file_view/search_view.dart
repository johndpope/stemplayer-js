// SearchView - Search interface matching AudioFileView Python app
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../audio_palette_service.dart';
import '../rust/lib.dart' as rust_lib;

class SearchView extends StatefulWidget {
  final void Function(String filePath, double matchStart, double matchEnd)? onResultSelected;

  const SearchView({
    super.key,
    this.onResultSelected,
  });

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab bar
          Container(
            color: const Color(0xFF2d2d2d),
            child: const TabBar(
              tabs: [
                Tab(text: 'Text Search'),
                Tab(text: 'Sounds-Like'),
              ],
              labelColor: Colors.white,
              unselectedLabelColor: Color(0xFF888888),
              indicatorColor: Color(0xFF4a9eff),
              dividerColor: Color(0xFF333333),
              labelStyle: TextStyle(fontSize: 12),
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              children: [
                _TextSearchTab(onResultSelected: widget.onResultSelected),
                _SoundsLikeSearchTab(onResultSelected: widget.onResultSelected),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Text Search Tab
class _TextSearchTab extends StatefulWidget {
  final void Function(String filePath, double matchStart, double matchEnd)? onResultSelected;

  const _TextSearchTab({this.onResultSelected});

  @override
  State<_TextSearchTab> createState() => _TextSearchTabState();
}

class _TextSearchTabState extends State<_TextSearchTab> {
  final AudioPaletteService _paletteService = AudioPaletteService();
  final TextEditingController _searchController = TextEditingController();
  List<rust_lib.SoundRecord> _results = [];
  bool _isSearching = false;
  String _selectedFormat = 'Any';
  double _minDuration = 0;
  double _maxDuration = 3600;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search input
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by filename...',
                    hintStyle: const TextStyle(color: Color(0xFF666666)),
                    filled: true,
                    fillColor: const Color(0xFF1e1e1e),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF444444)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF444444)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF4a9eff)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _search,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3d5a80),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
        ),
        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              const Text('Format:', style: TextStyle(color: Color(0xFF888888), fontSize: 11)),
              const SizedBox(width: 4),
              DropdownButton<String>(
                value: _selectedFormat,
                dropdownColor: const Color(0xFF2d2d2d),
                style: const TextStyle(color: Color(0xFFcccccc), fontSize: 11),
                underline: const SizedBox(),
                items: ['Any', 'WAV', 'MP3', 'AIFF', 'FLAC', 'OGG'].map((f) {
                  return DropdownMenuItem(value: f, child: Text(f));
                }).toList(),
                onChanged: (v) => setState(() => _selectedFormat = v ?? 'Any'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Results
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4a9eff)))
              : _results.isEmpty
              ? const Center(
            child: Text(
              'Enter a search term',
              style: TextStyle(color: Color(0xFF666666)),
            ),
          )
              : _buildResultsList(),
        ),
        // Status
        Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: const Color(0xFF2d2d2d),
          alignment: Alignment.centerLeft,
          child: Text(
            'Found ${_results.length} results',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final sound = _results[index];
        return ListTile(
          dense: true,
          tileColor: index % 2 == 1 ? const Color(0xFF252525) : null,
          title: Text(
            sound.filename,
            style: const TextStyle(color: Color(0xFFdddddd), fontSize: 12),
          ),
          subtitle: Text(
            '${_formatDuration(sound.duration)} • ${sound.format.toUpperCase()}',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
          ),
          onTap: () {
            widget.onResultSelected?.call(sound.filepath, 0, sound.duration);
          },
        );
      },
    );
  }

  Future<void> _search() async {
    if (_searchController.text.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      await _paletteService.initialize();
      final results = await _paletteService.searchSounds(_searchController.text);
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

// Sounds-Like Search Tab
class _SoundsLikeSearchTab extends StatefulWidget {
  final void Function(String filePath, double matchStart, double matchEnd)? onResultSelected;

  const _SoundsLikeSearchTab({this.onResultSelected});

  @override
  State<_SoundsLikeSearchTab> createState() => _SoundsLikeSearchTabState();
}

class _SoundsLikeSearchTabState extends State<_SoundsLikeSearchTab> {
  final AudioPaletteService _paletteService = AudioPaletteService();
  String? _selectedFile;
  double _threshold = 50;
  List<rust_lib.MatchResult> _results = [];
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Instructions
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Find sounds that are acoustically similar to a reference file.',
            style: TextStyle(color: Color(0xFF888888), fontSize: 11),
          ),
        ),
        // File picker
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1e1e1e),
                    border: Border.all(color: const Color(0xFF444444)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _selectedFile?.split('/').last ?? 'No file selected',
                    style: TextStyle(
                      color: _selectedFile != null ? const Color(0xFFcccccc) : const Color(0xFF666666),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _pickFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3a3a3a),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Browse...'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Threshold slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Text('Min Similarity:', style: TextStyle(color: Color(0xFF888888), fontSize: 11)),
              Expanded(
                child: Slider(
                  value: _threshold,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_threshold.round()}%',
                  activeColor: const Color(0xFF4a9eff),
                  inactiveColor: const Color(0xFF444444),
                  onChanged: (v) => setState(() => _threshold = v),
                ),
              ),
              Text('${_threshold.round()}%', style: const TextStyle(color: Color(0xFFcccccc), fontSize: 11)),
            ],
          ),
        ),
        // Search button
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedFile != null ? _search : null,
              icon: const Icon(Icons.search),
              label: const Text('Find Similar Sounds'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3d5a80),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF333333),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const Divider(color: Color(0xFF333333), height: 1),
        // Results table
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4a9eff)))
              : _results.isEmpty
              ? const Center(
            child: Text(
              'Select a file and click "Find Similar Sounds"',
              style: TextStyle(color: Color(0xFF666666)),
            ),
          )
              : _buildResultsTable(),
        ),
        // Export buttons
        if (_results.isNotEmpty) _buildExportBar(),
        // Status
        Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: const Color(0xFF2d2d2d),
          alignment: Alignment.centerLeft,
          child: Text(
            'Found ${_results.length} similar sounds',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsTable() {
    return Column(
      children: [
        // Header
        Container(
          height: 28,
          color: const Color(0xFF2d2d2d),
          child: const Row(
            children: [
              _ResultHeader('Filename', flex: 3),
              _ResultHeader('Score', flex: 1),
              _ResultHeader('Match Range', flex: 2),
              _ResultHeader('Duration', flex: 1),
            ],
          ),
        ),
        // Rows
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final result = _results[index];
              return _ResultRow(
                result: result,
                isAlternate: index % 2 == 1,
                onTap: () {
                  widget.onResultSelected?.call(
                    result.filepath,
                    result.matchStart,
                    result.matchEnd,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExportBar() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF2a2a2a),
        border: Border(
          top: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Text('Export:', style: TextStyle(color: Color(0xFF888888), fontSize: 11)),
          const SizedBox(width: 8),
          _ExportButton(label: 'MIDI', onPressed: _exportMidi),
          _ExportButton(label: 'CSV', onPressed: _exportCsv),
          _ExportButton(label: 'Markers', onPressed: _exportMarkers),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'aiff', 'flac', 'ogg', 'm4a'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFile = result.files.single.path);
    }
  }

  Future<void> _search() async {
    if (_selectedFile == null) return;

    setState(() => _isSearching = true);
    try {
      await _paletteService.initialize();
      final results = await _paletteService.findSimilarWithSegments(
        _selectedFile!,
        threshold: _threshold,
        maxResults: 50,
      );
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  Future<void> _exportMidi() async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export MIDI',
      fileName: 'matches.mid',
      type: FileType.custom,
      allowedExtensions: ['mid'],
    );

    if (result != null) {
      await _paletteService.exportToMidi(_results, result);
    }
  }

  Future<void> _exportCsv() async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export CSV',
      fileName: 'matches.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      await _paletteService.exportToCsv(_results, result);
    }
  }

  Future<void> _exportMarkers() async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Markers',
      fileName: 'matches.txt',
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null) {
      await _paletteService.exportToMarkers(_results, result);
    }
  }
}

class _ResultHeader extends StatelessWidget {
  final String label;
  final int flex;

  const _ResultHeader(this.label, {this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFaaaaaa),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final rust_lib.MatchResult result;
  final bool isAlternate;
  final VoidCallback? onTap;

  const _ResultRow({
    required this.result,
    required this.isAlternate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 28,
        color: isAlternate ? const Color(0xFF252525) : const Color(0xFF1e1e1e),
        child: Row(
          children: [
            // Filename
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  result.filename,
                  style: const TextStyle(color: Color(0xFFdddddd), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Score
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${result.score.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _getScoreColor(result.score),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            // Match range
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${_formatTime(result.matchStart)} - ${_formatTime(result.matchEnd)}',
                  style: const TextStyle(color: Color(0xFF88aaff), fontSize: 12),
                ),
              ),
            ),
            // Duration
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _formatTime(result.fileDuration),
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return const Color(0xFF4ade80); // Green
    if (score >= 60) return const Color(0xFFfacc15); // Yellow
    if (score >= 40) return const Color(0xFFfb923c); // Orange
    return const Color(0xFFf87171); // Red
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _ExportButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF3a3a3a),
          foregroundColor: const Color(0xFFcccccc),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 28),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}
