import 'package:flutter/material.dart';

class PickVideoHint extends StatelessWidget {
  const PickVideoHint({super.key,
    required this.pickVideo,
  });

  final VoidCallback pickVideo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('請先選擇影片'),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: pickVideo,
            child: Text('選擇影片'),
          ),
        ],
      ),
    );
  }
}
