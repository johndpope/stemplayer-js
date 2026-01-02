// CatalogView - MyPalette browser matching AudioFileView Python app
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../audio_palette_service.dart';
import '../rust/lib.dart' as rust_lib;

class CatalogView extends StatefulWidget {
  final void Function(String filePath, String fileName)? onSoundSelected;
  final void Function(String message)? onIndexingStarted;
  final void Function(int current, int total, String fileName)? onIndexingProgress;
  final void Function(int count)? onIndexingComplete;

  const CatalogView({
    super.key,
    this.onSoundSelected,
    this.onIndexingStarted,
    this.onIndexingProgress,
    this.onIndexingComplete,
  });

  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  final AudioPaletteService _paletteService = AudioPaletteService();
  List<rust_lib.SoundRecord> _sounds = [];
  String _selectedCategory = 'All Sounds';
  int? _selectedSoundId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  Future<void> _loadSounds() async {
    setState(() => _isLoading = true);
    try {
      await _paletteService.initialize();
      final sounds = await _paletteService.getAllSounds();
      setState(() {
        _sounds = sounds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        _buildToolbar(),
        // Main content with splitter
        Expanded(
          child: Row(
            children: [
              // Category tree
              SizedBox(
                width: 150,
                child: _buildCategoryTree(),
              ),
              // Divider
              Container(width: 1, color: const Color(0xFF333333)),
              // Sound table
              Expanded(child: _buildSoundTable()),
            ],
          ),
        ),
        // Status bar
        _buildStatusBar(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF2d2d2d),
        border: Border(
          bottom: BorderSide(color: Color(0xFF444444), width: 1),
        ),
      ),
      child: Row(
        children: [
          _ToolbarButton(
            icon: Icons.add,
            label: 'Add Files',
            onPressed: _addFiles,
          ),
          const SizedBox(width: 4),
          _ToolbarButton(
            icon: Icons.create_new_folder,
            label: 'Add Folder',
            onPressed: _addFolder,
          ),
          const Spacer(),
          _ToolbarButton(
            icon: Icons.refresh,
            label: 'Refresh',
            onPressed: _loadSounds,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTree() {
    return Container(
      color: const Color(0xFF252525),
      child: ListView(
        children: [
          _CategoryItem(
            name: 'All Sounds',
            icon: Icons.library_music,
            isSelected: _selectedCategory == 'All Sounds',
            onTap: () => setState(() => _selectedCategory = 'All Sounds'),
          ),
          const Divider(color: Color(0xFF333333), height: 1),
          // TODO: Add custom categories from database
          _CategoryItem(
            name: 'Drums',
            icon: Icons.folder,
            isSelected: _selectedCategory == 'Drums',
            onTap: () => setState(() => _selectedCategory = 'Drums'),
          ),
          _CategoryItem(
            name: 'Bass',
            icon: Icons.folder,
            isSelected: _selectedCategory == 'Bass',
            onTap: () => setState(() => _selectedCategory = 'Bass'),
          ),
          _CategoryItem(
            name: 'Synths',
            icon: Icons.folder,
            isSelected: _selectedCategory == 'Synths',
            onTap: () => setState(() => _selectedCategory = 'Synths'),
          ),
          _CategoryItem(
            name: 'FX',
            icon: Icons.folder,
            isSelected: _selectedCategory == 'FX',
            onTap: () => setState(() => _selectedCategory = 'FX'),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundTable() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4a9eff)),
      );
    }

    if (_sounds.isEmpty) {
      return const Center(
        child: Text(
          'No sounds in MyPalette\nClick "Add Files" or "Add Folder" to get started',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF666666)),
        ),
      );
    }

    return Container(
      color: const Color(0xFF1e1e1e),
      child: Column(
        children: [
          // Table header
          Container(
            height: 28,
            color: const Color(0xFF2d2d2d),
            child: const Row(
              children: [
                _TableHeader('Filename', flex: 3),
                _TableHeader('Duration', flex: 1),
                _TableHeader('Format', flex: 1),
                _TableHeader('Rate', flex: 1),
              ],
            ),
          ),
          // Table body
          Expanded(
            child: ListView.builder(
              itemCount: _sounds.length,
              itemBuilder: (context, index) {
                final sound = _sounds[index];
                final isSelected = _selectedSoundId == sound.id.toInt();
                return _SoundRow(
                  sound: sound,
                  isSelected: isSelected,
                  isAlternate: index % 2 == 1,
                  onTap: () {
                    setState(() => _selectedSoundId = sound.id.toInt());
                    widget.onSoundSelected?.call(sound.filepath, sound.filename);
                  },
                  onDoubleTap: () {
                    // Play sound
                  },
                  onSecondaryTap: (details) => _showSoundContextMenu(details, sound),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF2d2d2d),
        border: Border(
          top: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${_sounds.length} sounds in MyPalette',
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'aiff', 'flac', 'ogg', 'm4a'],
    );

    if (result != null && result.files.isNotEmpty) {
      widget.onIndexingStarted?.call('Adding ${result.files.length} files...');

      int added = 0;
      for (int i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        if (file.path != null) {
          widget.onIndexingProgress?.call(i + 1, result.files.length, file.name);
          try {
            await _paletteService.addSound(file.path!);
            added++;
          } catch (e) {
            // Skip failed files
          }
        }
      }

      widget.onIndexingComplete?.call(added);
      _loadSounds();
    }
  }

  Future<void> _addFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      final dir = Directory(result);
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) {
        final ext = f.path.split('.').last.toLowerCase();
        return ['wav', 'mp3', 'aiff', 'flac', 'ogg', 'm4a'].contains(ext);
      })
          .toList();

      if (files.isNotEmpty) {
        widget.onIndexingStarted?.call('Adding ${files.length} files...');

        int added = 0;
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          widget.onIndexingProgress?.call(i + 1, files.length, file.path.split('/').last);
          try {
            await _paletteService.addSound(file.path);
            added++;
          } catch (e) {
            // Skip failed files
          }
        }

        widget.onIndexingComplete?.call(added);
        _loadSounds();
      }
    }
  }

  void _showSoundContextMenu(TapDownDetails details, rust_lib.SoundRecord sound) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF2d2d2d),
      items: [
        const PopupMenuItem<String>(
          value: 'play',
          child: Row(
            children: [
              Icon(Icons.play_arrow, size: 18, color: Color(0xFFcccccc)),
              SizedBox(width: 8),
              Text('Play', style: TextStyle(color: Color(0xFFcccccc))),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'assign',
          child: Row(
            children: [
              Icon(Icons.folder, size: 18, color: Color(0xFFcccccc)),
              SizedBox(width: 8),
              Text('Assign to Category', style: TextStyle(color: Color(0xFFcccccc))),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: Color(0xFFff6666)),
              SizedBox(width: 8),
              Text('Remove from MyPalette', style: TextStyle(color: Color(0xFFff6666))),
            ],
          ),
        ),
      ],
    ).then((value) async {
      if (value == 'remove') {
        await _paletteService.removeSound(sound.id.toInt());
        _loadSounds();
      }
    });
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: const Color(0xFFaaaaaa)),
      label: Text(
        label,
        style: const TextStyle(color: Color(0xFFaaaaaa), fontSize: 12),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _CategoryItem({
    required this.name,
    required this.icon,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: isSelected ? const Color(0xFF3d5a80) : null,
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF888888)),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFcccccc),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String label;
  final int flex;

  const _TableHeader(this.label, {this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
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

class _SoundRow extends StatelessWidget {
  final rust_lib.SoundRecord sound;
  final bool isSelected;
  final bool isAlternate;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final void Function(TapDownDetails)? onSecondaryTap;

  const _SoundRow({
    required this.sound,
    required this.isSelected,
    required this.isAlternate,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onSecondaryTapDown: onSecondaryTap,
      child: Container(
        height: 28,
        color: isSelected
            ? const Color(0xFF3d5a80)
            : isAlternate
            ? const Color(0xFF252525)
            : const Color(0xFF1e1e1e),
        child: Row(
          children: [
            _TableCell(sound.filename, flex: 3),
            _TableCell(_formatDuration(sound.duration), flex: 1),
            _TableCell(sound.format.toUpperCase(), flex: 1),
            _TableCell('${(sound.sampleRate / 1000).toStringAsFixed(1)}k', flex: 1),
          ],
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final int flex;

  const _TableCell(this.text, {this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFdddddd),
            fontSize: 12,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
