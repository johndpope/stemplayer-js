// AudioFileView - FSPalette-style audio browser and editor
import 'package:flutter/material.dart';
import 'src/audio_file_view/audio_file_view.dart';

void main() {
  runApp(const AudioFileViewApp());
}

class AudioFileViewApp extends StatelessWidget {
  const AudioFileViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AudioFileView',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1e1e1e),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4a9eff),
          surface: Color(0xFF2d2d2d),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF2d2d2d),
        ),
      ),
      home: const AudioFileView(),
    );
  }
}
