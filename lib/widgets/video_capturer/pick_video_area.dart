import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/widgets/common/area.dart';

class PickVideoArea extends StatelessWidget {
  const PickVideoArea({super.key,
    required this.pickVideo,
    this.currentVideoPath,
  });

  final VoidCallback pickVideo;

  final String? currentVideoPath;

  @override
  Widget build(BuildContext context) {
    return ContentArea(
      title: '選擇影片',
      child: Row(
        children: [
          Expanded(child: Text('影片: $currentVideoPath')),
          IconButton(onPressed: pickVideo, icon: const Icon(Icons.video_file_outlined)),
        ],
      ),
    );
  }
}
