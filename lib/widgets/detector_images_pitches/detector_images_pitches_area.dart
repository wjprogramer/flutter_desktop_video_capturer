import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/widgets/common/area.dart';

class DetectorImagesPitchesArea extends StatelessWidget {
  const DetectorImagesPitchesArea({super.key, this.onClearGridLines, this.onLoadGridLines});

  final VoidCallback? onClearGridLines;

  final VoidCallback? onLoadGridLines;

  @override
  Widget build(BuildContext context) {
    return ContentArea(
      title: '辨識圖片相關',
      child: Wrap(
        alignment: WrapAlignment.start,
        runAlignment: WrapAlignment.start,
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(onPressed: onClearGridLines, icon: const Icon(Icons.clear), label: const Text('清空')),
          FilledButton.icon(onPressed: onLoadGridLines, icon: const Icon(Icons.download), label: Text('載入')),
        ],
      ),
    );
  }
}
