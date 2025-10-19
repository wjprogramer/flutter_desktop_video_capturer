import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/models.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/video_capturer.dart';
import 'package:flutter_desktop_video_capturer/utils/toast.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

mixin VideoCapturerViewMixin<T extends StatefulWidget> on State<T> {
  final videoCapturer = VideoCapturer();

  VideoPlayerController? videoController;

  String? get _videoPath => videoCapturer.videoPath;

  Rect? get _rectVideoPx => videoCapturer.rectVideoPx;

  Future<void> pickVideoForCapturer({VoidCallback? onSuccessAndBeforeUpdatePage}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.single.path == null) {
      return;
    }

    videoController?.dispose();

    final filePath = result.files.single.path!;
    final c = VideoPlayerController.file(File(filePath));
    videoController = c;
    await c.initialize();

    await c.setVolume(0);

    // 這裡的 size 是以「畫面邏輯像素比例」呈現的寬高比，實際像素用比例換算即可
    // 多數情況可直接把 value.size 當作影片的像素比例，等比縮放即可。
    final vs = c.value.size; // e.g., Size(1920, 1080) 或 300x300

    final videoSizePx = Size(vs.width.roundToDouble(), vs.height.roundToDouble());
    onSuccessAndBeforeUpdatePage?.call();

    c.play();

    videoCapturer.setVideoPath(filePath, videoSizePx);
    setState(() {});
  }

  Future<void> tryRunCapturer() async {
    if (_videoPath == null) {
      showToast('請先選擇影片');
      return;
    }

    if (_rectVideoPx == null) {
      showToast('請先選取擷取區域');
      return;
    }

    final videoName = p.basenameWithoutExtension(_videoPath!);
    final appDocDir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final middle =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
    final outputPath = p.join(appDocDir.path, 'export_${middle}_$videoName');

    if (videoController == null) {
      return;
    }

    await videoCapturer.runCapture(
      inputPath: _videoPath!,
      outputDir: outputPath,
      start: Duration.zero,
      interval: const Duration(seconds: 1),
      rect: _rectVideoPx!,
      //Rect.fromLTWH(0, 0, 2160, 1440),
      videoDuration: videoController!.value.duration,
    );
  }
}
