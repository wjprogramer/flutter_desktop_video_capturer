import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/page.dart';

void main() {
  runApp(const VideoFrameExtractorApp());
}

class VideoFrameExtractorApp extends StatelessWidget {
  const VideoFrameExtractorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Frame Extractor',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}
