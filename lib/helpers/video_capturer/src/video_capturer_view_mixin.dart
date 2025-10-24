import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/video_capturer.dart';
import 'package:flutter_desktop_video_capturer/third_party/uuid/uuid.dart';
import 'package:flutter_desktop_video_capturer/utilities/file_structure_utility.dart';
import 'package:flutter_desktop_video_capturer/utilities/formatter.dart';
import 'package:flutter_desktop_video_capturer/utils/toast.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

/// 使用前需要初始化 (呼叫 [initVideoCapturer])
mixin VideoCapturerViewMixin<T extends StatefulWidget> on State<T> {
  final String taskId = MyUuid.generate();

  late final VideoCapturer videoCapturer;

  VideoPlayerController? videoController;

  Map<Duration, Uint8List> _previewBytes = {};

  String? get _videoPath => videoCapturer.videoPath;

  Rect? get _rectVideoPx => videoCapturer.rectVideoPx;

  void initVideoCapturer() {
    videoCapturer = VideoCapturer();
  }

  Future<void> pickVideoForCapturer() async {
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

    c.play();

    videoCapturer.setVideoPath(filePath, videoSizePx);
    setState(() {});
  }

  Future<void> reloadPreviewImages() async {
    final c = videoController;
    if (c == null || _videoPath == null) return;

    final segments = videoCapturer.buildSegments(c.value.duration);
    final List<Duration> captureDurations = videoCapturer.plannedCaptureTimesFromSegments(segments);

    // 可視需求：避免太重，先限制數量，例如前 50 張
    // final times = captureDurations.take(50);
    final times = captureDurations;

    final Map<Duration, Uint8List> tmp = {};
    for (final t in times) {
      final bytes = await _extractFrameBytes(
        inputPath: _videoPath!,
        at: t,
        cropVideoPx: videoCapturer.rectVideoPx, // 若不要裁切，傳 null
        format: 'png',
      );
      if (bytes != null) tmp[t] = bytes;
    }

    if (!mounted) return;
    setState(() {
      _previewBytes = tmp;
    });
  }

  Future<Uint8List?> _extractFrameBytes({
    required String inputPath,
    required Duration at,
    Rect? cropVideoPx, // 影片像素座標（可為 null 表示不裁切）
    String format = 'png', // 'png' 或 'jpeg'
  }) async {
    // ffmpeg args：單張影格 → stdout (image2pipe)
    final args = <String>[
      '-hide_banner',
      '-loglevel', 'error',
      '-ss', (at.inMilliseconds / 1000).toStringAsFixed(3),
      '-i', inputPath,
      '-frames:v', '1',
      if (cropVideoPx != null) ...[
        '-vf',
        'crop=${cropVideoPx.width.round()}:${cropVideoPx.height.round()}:${cropVideoPx.left.round()}:${cropVideoPx.top.round()}',
      ],
      '-f', 'image2pipe',
      '-vcodec', (format == 'png') ? 'png' : 'mjpeg',
      '-', // 輸出到 stdout
    ];

    final process = await Process.start('ffmpeg', args);
    // 讀 stdout → bytes
    final bb = BytesBuilder(copy: false);
    // 將 stderr 清空避免阻塞（可視需要把內容寫到你的 console）
    process.stderr.listen((_) {});

    await for (final chunk in process.stdout) {
      bb.add(chunk);
    }
    final code = await process.exitCode;
    if (code != 0) return null; // 失敗就回 null（也可丟例外）

    return bb.toBytes();
  }

  // === 規則 / 停止點 ===
  void addRuleAtCurrent() {
    final c = videoController;
    if (c == null || videoCapturer.rectVideoPx == null) return;
    final now = c.value.position;
    videoCapturer.addRuleAt(now);
    setState(() {});
  }

  void addStopAtCurrent() {
    final c = videoController;
    if (c == null) return;
    final now = c.value.position;
    videoCapturer.addStopAt(now);
    setState(() {});
  }

  void removeRule(int index) {
    videoCapturer.removeRuleAt(index);
    setState(() {});
  }

  void removeStop(int index) {
    videoCapturer.removeStopAt(index);
    setState(() {});
  }

  /// 上一個擷取點
  void goToPrevStepInCapturer() {
    final videoController = this.videoController;
    if (videoController == null) return;
    final segments = videoCapturer.buildSegments(videoController.value.duration);
    final capTimes = videoCapturer.plannedCaptureTimesFromSegments(segments);
    if (capTimes.isEmpty) return;
    // 往前找（略小一點避免剛好在點上也算下一個）
    final idx = _indexOfPrevCapture(capTimes, videoController.value.position - const Duration(milliseconds: 1));
    if (idx >= 0) {
      videoController.seekTo(capTimes[idx]);
      setState(() {});
    }
  }

  /// 下一個擷取點
  void goToNextStepInCapturer() {
    final videoController = this.videoController;
    if (videoController == null) return;
    final segments = videoCapturer.buildSegments(videoController.value.duration);
    final capTimes = videoCapturer.plannedCaptureTimesFromSegments(segments);
    if (capTimes.isEmpty) return;
    final idx = _indexOfPrevCapture(capTimes, videoController.value.position);
    if (idx + 1 < capTimes.length) {
      videoController.seekTo(capTimes[idx + 1]);
      setState(() {});
    }
  }

  int _indexOfPrevCapture(List<Duration> times, Duration pos) {
    return videoCapturer.indexOfPrevCapture(times, pos);
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
    final outputPath = (await getCapturerOutputDir()).path;

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

  Future<Directory> getCapturerOutputDir() async {
    return FileStructureUtility.generateTempVideoCaptureDir(taskId);
  }

  /// 用最近開始點推算間隔
  void updateIntervalFromLastRule(VideoPlayerController videoController) {
    final pos = videoController.value.position;

    final nearest = videoCapturer.nearestRuleFor(pos);
    if (nearest == null) {
      showToast('找不到最近的開始點（中間有停止點或尚未建立規則）');
      return;
    }

    final ms = (pos - nearest.start).inMilliseconds.abs();
    if (ms <= 0) {
      showToast('目前時間與最近開始點相同，無法推算間隔');
      return;
    }

    videoCapturer.setDefaultIntervalMs(ms);
    setState(() {});
    showToast('已將預設間隔設為 $ms ms（最近開始點：${Formatter.durationText(nearest.start)} → 目前：${Formatter.durationText(pos)}）');

    // 若你想同時把「最近那條 rule 的 interval」也一併更新，可解除下列註解：
    // final idx = rules.indexWhere((r) => r.start == nearest.start);
    // if (idx >= 0) setState(() => rules[idx] = rules[idx].copyWith(interval: Duration(milliseconds: ms)));
  }

  // void reloadPreviewImages() {
  //   final videoController = this.videoController;
  //   if (videoController == null) return;
  //   final segments = videoCapturer.buildSegments(videoController.value.duration);
  //   final captureDurations = videoCapturer.plannedCaptureTimesFromSegments(segments);
  // }
}
