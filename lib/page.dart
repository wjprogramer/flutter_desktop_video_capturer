import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/toast.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'other.dart';

class CaptureRule {
  CaptureRule({required this.start, this.end, required this.interval, required this.rect});

  final Duration start;
  final Duration? end; // 實際運行前會依 stop/rule 自動計算
  final Duration interval;
  final Rect rect; // 影片像素座標

  Map<String, dynamic> toJson() => {
    "start_ms": start.inMilliseconds,
    "interval_ms": interval.inMilliseconds,
    "rect": {"x": rect.left.toInt(), "y": rect.top.toInt(), "w": rect.width.toInt(), "h": rect.height.toInt()},
  };

  CaptureRule copyWith({Duration? start, ValueObject<Duration>? end, Duration? interval, Rect? rect}) {
    return CaptureRule(
      start: start ?? this.start,
      end: end != null ? end.value : this.end,
      interval: interval ?? this.interval,
      rect: rect ?? this.rect,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scrollController = ScrollController();
  final List<String> _logs = [];

  VideoPlayerController? _controller;
  Rect? selectedRect;
  Offset? dragStart;
  Offset? dragEnd;

  String? videoPath;

  // 以「影片像素」為座標系來存
  Rect? rectVideoPx;
  Offset? dragStartVideoPx;
  Size? videoSizePx; // 例如 1920x1080

  var _isPlayingBeforeChangeDuration = false;

  // 規則與停止點
  final List<CaptureRule> rules = [];
  final List<Duration> stopPoints = []; // 單純的停止點時間列表（毫秒精度）

  // 預設加入規則的 interval（可在 UI 調整每條）
  int _defaultIntervalMs = 1200;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addLog(String text) {
    setState(() {
      _logs.insert(0, text);
    });
    _scrollController.jumpTo(0);
  }

  Future<void> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.single.path == null) {
      return;
    }

    _controller?.dispose();

    final filePath = result.files.single.path!;
    final c = VideoPlayerController.file(File(filePath));
    _controller = c;
    await c.initialize();

    await c.setVolume(0);

    // 這裡的 size 是以「畫面邏輯像素比例」呈現的寬高比，實際像素用比例換算即可
    // 多數情況可直接把 value.size 當作影片的像素比例，等比縮放即可。
    final vs = c.value.size; // e.g., Size(1920, 1080) 或 300x300

    setState(() {});
    videoSizePx = Size(vs.width.roundToDouble(), vs.height.roundToDouble());
    rectVideoPx = null; // 重選
    dragStartVideoPx = null;

    c.play();

    setState(() {
      videoPath = filePath;
    });
  }

  // 把螢幕上的 localPosition（Stack child 的座標，單位邏輯 px）映射到「影片像素座標」
  Offset? _screenToVideo(Offset p, Size paintSize) {
    if (videoSizePx == null) return null;

    // 以 BoxFit.contain 計算影片顯示矩形（在 paintSize 內）
    final vw = videoSizePx!.width;
    final vh = videoSizePx!.height;
    final scale = math.min(paintSize.width / vw, paintSize.height / vh);
    final displayW = vw * scale;
    final displayH = vh * scale;
    final dx = (paintSize.width - displayW) / 2.0;
    final dy = (paintSize.height - displayH) / 2.0;
    final displayRect = Rect.fromLTWH(dx, dy, displayW, displayH);

    // 若座標在影片外的 letterbox 區域，忽略
    if (!displayRect.contains(p)) return null;

    // 反投影：先扣掉 offset，再除以 scale
    final vx = (p.dx - displayRect.left) / scale;
    final vy = (p.dy - displayRect.top) / scale;

    // 夾在影片邊界內（避免負數/超界）
    final clampedX = vx.clamp(0.0, vw);
    final clampedY = vy.clamp(0.0, vh);
    return Offset(clampedX, clampedY);
  }

  // 把「影片像素座標」轉回螢幕（為了畫框用）
  Rect _videoRectToScreen(Rect rVideo, Size paintSize) {
    final vw = videoSizePx!.width;
    final vh = videoSizePx!.height;
    final scale = math.min(paintSize.width / vw, paintSize.height / vh);
    final displayW = vw * scale;
    final displayH = vh * scale;
    final dx = (paintSize.width - displayW) / 2.0;
    final dy = (paintSize.height - displayH) / 2.0;

    return Rect.fromLTWH(
      dx + rVideo.left * scale,
      dy + rVideo.top * scale,
      rVideo.width * scale,
      rVideo.height * scale,
    );
  }

  void _onPanStart(DragStartDetails d, Size paintSize) {
    final v = _screenToVideo(d.localPosition, paintSize);
    if (v == null) return;
    setState(() {
      dragStartVideoPx = v;
      rectVideoPx = null;
    });
  }

  void _onPanUpdate(DragUpdateDetails d, Size paintSize) {
    if (dragStartVideoPx == null) return;
    final v = _screenToVideo(d.localPosition, paintSize);
    if (v == null) return;
    setState(() {
      rectVideoPx = Rect.fromPoints(dragStartVideoPx!, v);
      print('=============> ${rectVideoPx!.left} ${rectVideoPx!.top} ${rectVideoPx!.width} ${rectVideoPx!.height}');
    });
  }

  void _onPanEnd() {
    setState(() {
      dragStartVideoPx = null; // 結束拖曳，保留 rectVideoPx
    });
    if (rectVideoPx != null) {
      final r = rectVideoPx!;
      debugPrint(
        "選取(影片像素): x=${r.left.toStringAsFixed(1)}, y=${r.top.toStringAsFixed(1)}, "
        "w=${r.width.toStringAsFixed(1)}, h=${r.height.toStringAsFixed(1)}",
      );
    }
  }

  // === 規則 / 停止點 ===
  void _addRuleAtCurrent() {
    final c = _controller;
    if (c == null || rectVideoPx == null) return;
    final now = c.value.position;
    // 避免重複時間的規則（允許但會導致 0 長度段）
    setState(() {
      rules.add(
        CaptureRule(
          start: now,
          end: null, // 執行前會自動推導
          interval: Duration(milliseconds: _defaultIntervalMs),
          rect: rectVideoPx!,
        ),
      );
      rules.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  void _addStopAtCurrent() {
    final c = _controller;
    if (c == null) return;
    final now = c.value.position;
    setState(() {
      if (!stopPoints.any((d) => (d - now).inMilliseconds.abs() <= 1)) {
        stopPoints.add(now);
        stopPoints.sort((a, b) => a.compareTo(b));
      }
    });
  }

  void _removeRule(int index) {
    setState(() => rules.removeAt(index));
  }

  void _removeStop(int index) {
    setState(() => stopPoints.removeAt(index));
  }

  // 由 rules + stopPoints 推導每段擷取區間
  List<_Segment> _buildSegments(Duration videoDuration) {
    final sortedRules = [...rules]..sort((a, b) => a.start.compareTo(b.start));
    final stops = [...stopPoints]..sort((a, b) => a.compareTo(b));

    final segs = <_Segment>[];
    for (int i = 0; i < sortedRules.length; i++) {
      final r = sortedRules[i];
      // 下一個規則起始
      Duration? nextRuleStart;
      if (i + 1 < sortedRules.length) nextRuleStart = sortedRules[i + 1].start;

      // 下一個停止點（在 r.start 之後）
      Duration? nextStop;
      for (final s in stops) {
        if (s > r.start) {
          nextStop = s;
          break;
        }
      }

      // 候選 end = [nextRuleStart, nextStop, videoEnd]
      Duration end = videoDuration;
      if (nextRuleStart != null && nextRuleStart < end) end = nextRuleStart;
      if (nextStop != null && nextStop < end) end = nextStop;

      if (end > r.start && r.interval.inMilliseconds > 0 && r.rect.width > 0 && r.rect.height > 0) {
        segs.add(_Segment(rule: r.copyWith(end: ValueObject(end))));
      }
    }
    return segs;
  }

  Future<void> runCapture({
    required String inputPath,
    required String outputDir,
    required Duration start, // 保留參數相容，但實際改用 rules
    required Duration interval, // 保留參數相容
    required Rect rect,
  }) async {
    if (videoPath == null || rules.isEmpty || rectVideoPx == null || _controller == null) return;
    final newRules = rules.map((e) => e.copyWith(rect: rect)).toList();

    final segs = _buildSegments(_controller!.value.duration);
    if (segs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('沒有有效的擷取區段，請至少加入一個規則（開始點）')));
      return;
    }

    // crop=w:h:x:y
    final crop = "crop=${rect.width.toInt()}:${rect.height.toInt()}:${rect.left.toInt()}:${rect.top.toInt()}";

    // 計算 fps (interval 毫秒 -> 1 / 秒數)
    final fps = 1 / (interval.inMilliseconds / 1000.0);

    // 建立輸出資料夾
    final dir = Directory(outputDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final projectDir = Directory(p.join(dir.path, "captures"));
    if (!projectDir.existsSync()) {
      projectDir.createSync(recursive: true);
    }

    final meta = <String, dynamic>{
      "video": videoPath,
      "rect": {
        "x": rectVideoPx!.left.round(),
        "y": rectVideoPx!.top.round(),
        "w": rectVideoPx!.width.round(),
        "h": rectVideoPx!.height.round(),
      },
      "rules": rules
          .map((r) => {"start_ms": r.start.inMilliseconds, "interval_ms": r.interval.inMilliseconds})
          .toList(),
      "stops_ms": stopPoints.map((e) => e.inMilliseconds).toList(),
      "segments": <Map<String, dynamic>>[],
    };

    _addLog('共 ${segs.length} 段要擷取');

    final outputPattern = "${dir.path}${Platform.pathSeparator}frame_%04d.png";

    int segmentIndex = 0;

    for (int i = 0; i < segs.length; i++) {
      final seg = segs[i];
      final r = seg.rule; // 已帶有 end
      final segDir = Directory(p.join(projectDir.path, 'seg_$i'));
      if (!segDir.existsSync()) segDir.createSync(recursive: true);

      final x = r.rect.left.round();
      final y = r.rect.top.round();
      final w = r.rect.width.round();
      final h = r.rect.height.round();

      Future<void> forceCaptureSegStart() async {
        // 先強制擷取「段落起點」的一張
        final startStillPath = p.join(segDir.path, 'frame_start.png');
        final argsStart = [
          '-hide_banner',
          '-loglevel', 'info',
          '-ss', (r.start.inMilliseconds / 1000).toStringAsFixed(3),
          '-i', inputPath,
          '-vf', 'crop=$w:$h:$x:$y',
          '-frames:v', '1',
          startStillPath,
        ];
        _addLog('執行(起點單張): ffmpeg ${argsStart.join(' ')}');
        try {
          final pStart = await Process.start('ffmpeg', argsStart);
          pStart.stdout.transform(SystemEncoding().decoder).listen((d) => _addLog('stdout: $d'));
          pStart.stderr.transform(SystemEncoding().decoder).listen((d) => _addLog('stderr: $d'));
          final codeStart = await pStart.exitCode;
          _addLog('起點單張完成 seg_$i，exit=$codeStart');
        } catch (e) {
          _addLog('起點單張失敗 seg_$i: $e');
        }
      }
      await forceCaptureSegStart();

      final fps = 1 / (r.interval.inMilliseconds / 1000.0);
      final durationSec = ((r.end ?? _controller!.value.duration) - r.start).inMilliseconds / 1000.0;

      final args = [
        '-hide_banner',
        '-loglevel',
        'info',
        '-ss',
        (r.start.inMilliseconds / 1000).toStringAsFixed(3),
        '-i',
        inputPath,
        '-t',
        durationSec.toStringAsFixed(3),
        '-vf',
        'crop=$w:$h:$x:$y,fps=$fps',
        p.join(segDir.path, 'frame_%04d.png'),
      ];

      _addLog('執行: ffmpeg ${args.join(' ')}');
      try {
        final process = await Process.start('ffmpeg', args);
        process.stdout.transform(SystemEncoding().decoder).listen((data) => _addLog('stdout: $data'));
        process.stderr.transform(SystemEncoding().decoder).listen((data) => _addLog('stderr: $data'));
        final code = await process.exitCode;
        _addLog('完成 seg_$i，exit=$code');
      } catch (e) {
        _addLog('啟動 ffmpeg 失敗: $e');
      }

      // 計劃擷取時間（理想值）
      final plannedTimes = <int>[];
      for (
        int t = r.start.inMilliseconds;
        t <= (r.end?.inMilliseconds ?? r.start.inMilliseconds);
        t += r.interval.inMilliseconds
      ) {
        plannedTimes.add(t);
      }

      meta["segments"].add({
        "index": i,
        "start_ms": r.start.inMilliseconds,
        "end_ms": r.end?.inMilliseconds,
        "interval_ms": r.interval.inMilliseconds,
        "output_dir": segDir.path,
        "planned_capture_times_ms": plannedTimes,
      });
    }

    // for (var rule in newRules) {
    //   final segDir = Directory(p.join(projectDir.path, "seg_$segmentIndex"));
    //   if (!segDir.existsSync()) segDir.createSync();
    //
    //   final crop = "crop=${rule.rect.width}:${rule.rect.height}:${rule.rect.left}:${rule.rect.top}";
    //   final fps = 1 / (rule.interval.inMilliseconds / 1000.0);
    //
    //   final cmd =
    //       '-ss ${rule.start.inSeconds} -i "$videoPath" -vf "$crop,fps=$fps" "${p.join(segDir.path, "frame_%04d.png")}"';
    //
    //   // ffmpeg command
    //   final args = ["-ss", start.inSeconds.toString(), "-i", inputPath, "-vf", "$crop,fps=$fps", outputPattern];
    //
    //   print("Running ffmpeg: $cmd");
    //
    //   // await FFmpegKit.execute(cmd);
    //   final process = await Process.start("ffmpeg", args);
    //
    //   // 監聽 stdout/stderr
    //   process.stdout.transform(SystemEncoding().decoder).listen((data) {
    //     _addLog(data);
    //   });
    //   process.stderr.transform(SystemEncoding().decoder).listen((data) {
    //     _addLog(data);
    //   });
    //
    //   final exitCode = await process.exitCode;
    //   print("ffmpeg 完成，exit code: $exitCode");
    //
    //   meta["segments"].add({"rule": rule.toJson(), "output_dir": segDir.path});
    //
    //   segmentIndex++;
    // }

    final metaFile = File(p.join(projectDir.path, "meta.json"));
    // await metaFile.writeAsString(jsonEncode(meta));
    await metaFile.writeAsString(const JsonEncoder.withIndent(' ').convert(meta));
    // print("Meta saved: ${metaFile.path}");
    _addLog("Meta saved: ${metaFile.path}");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("擷取完成，輸出到 ${projectDir.path}")));
    }
  }

  Future<List<String>> buildFfmpegArgs({
    required String inputPath,
    required String outputPattern, // e.g. /path/seg_0/frame_%04d.png
    required Duration start,
    required Duration interval,
    required Rect rectVideoPx,
  }) async {
    // 影片像素 → 整數
    final x = rectVideoPx.left.round();
    final y = rectVideoPx.top.round();
    final w = rectVideoPx.width.round();
    final h = rectVideoPx.height.round();

    final fps = 1 / (interval.inMilliseconds / 1000.0); // 例: 1/0.2 = 5
    return [
      '-ss',
      start.inMilliseconds >= 0 ? (start.inMilliseconds / 1000).toStringAsFixed(3) : '0',
      '-i',
      inputPath,
      '-vf',
      'crop=$w:$h:$x:$y,fps=$fps',
      outputPattern,
    ];
  }

  void addSampleRule() {
    // 測試用的規則
    rules.add(
      CaptureRule(
        start: const Duration(seconds: 10),
        interval: const Duration(milliseconds: 1200),
        rect: const Rect.fromLTWH(100, 200, 400, 100),
      ),
    );
    setState(() {});
  }

  String _durationText(Duration d) {
    final s = d.inSeconds;
    final m = (s / 60).floor();
    final ms = d.inMilliseconds.remainder(1000);

    final mText = m.toString().padLeft(2, '0');
    final sText = s.remainder(60).toString().padLeft(2, '0');
    final msText = ms.toString().padLeft(3, '0');

    return '$mText:$sText.$msText';
  }

  // 從 segments 算出所有「預計擷取時間點」(已含每個 rule 的 start)
  List<Duration> _plannedCaptureTimesFromSegments(List<_Segment> segs) {
    final out = <Duration>[];
    for (final seg in segs) {
      final r = seg.rule;
      final startMs = r.start.inMilliseconds;
      final endMs = (r.end ?? r.start).inMilliseconds;
      final step = r.interval.inMilliseconds;
      if (step <= 0) continue;
      for (int t = startMs; t <= endMs; t += step) {
        out.add(Duration(milliseconds: t));
      }
    }
    out.sort((a, b) => a.compareTo(b));
    // 去重（避免鄰接段落首尾重疊）
    final dedup = <Duration>[];
    for (final d in out) {
      if (dedup.isEmpty || dedup.last != d) dedup.add(d);
    }
    return dedup;
  }

  // 找到「<= 當前位置」的擷取點 index（不存在回傳 -1）
  int _indexOfPrevCapture(List<Duration> times, Duration pos) {
    int lo = 0, hi = times.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (times[mid] <= pos) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  @override
  Widget build(BuildContext context) {
    final videoController = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text("Video Frame Extractor")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  ElevatedButton(onPressed: pickVideo, child: const Text("選擇影片")),
                  if (videoPath != null) Text("影片: $videoPath"),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: addSampleRule, child: const Text("加入範例擷取規則")),
                  Text("目前規則數量: ${rules.length}"),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (videoPath == null) {
                        showToast("請先選擇影片");
                        return;
                      }

                      if (rectVideoPx == null) {
                        showToast("請先選取擷取區域");
                        return;
                      }

                      final videoName = p.basenameWithoutExtension(videoPath!);
                      final appDocDir = await getApplicationDocumentsDirectory();
                      final outputPath = p.join(appDocDir.path, 'export_$videoName');

                      runCapture(
                        inputPath: videoPath!,
                        outputDir: outputPath,
                        start: Duration.zero,
                        interval: const Duration(seconds: 1),
                        rect: rectVideoPx!, //Rect.fromLTWH(0, 0, 2160, 1440),
                      );
                    },
                    child: const Text("開始擷取"),
                  ),
                  videoController == null
                      ? const Text("請先選擇影片")
                      : Container(
                          color: Colors.black,
                          width: double.infinity,
                          child: AspectRatio(
                            aspectRatio: videoController.value.aspectRatio,
                            child: Stack(
                              children: [
                                VideoPlayer(videoController),
                                // 透明互動層
                                Positioned.fill(
                                  child: LayoutBuilder(
                                    builder: (context, box) {
                                      final paintSize = Size(box.maxWidth, box.maxHeight); // 當前顯示大小
                                      return GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanStart: (d) => _onPanStart(d, paintSize),
                                        onPanUpdate: (d) => _onPanUpdate(d, paintSize),
                                        onPanEnd: (_) => _onPanEnd(),
                                        child: CustomPaint(
                                          painter: RectOnVideoPainter(
                                            rectVideoPx: rectVideoPx,
                                            toScreen: (rv) => _videoRectToScreen(rv, paintSize),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  if (videoController != null) ...[
                    ValueListenableBuilder(
                      valueListenable: videoController,
                      builder: (context, value, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      if (videoController.value.isPlaying) {
                                        videoController.pause();
                                      } else {
                                        videoController.play();
                                      }
                                    },
                                    icon: Icon(videoController.value.isPlaying ? Icons.pause : Icons.play_arrow),
                                  ),
                                  Text(
                                    '${_durationText(videoController.value.position)} / ${_durationText(videoController.value.duration)}',
                                  ),
                                  // 快速設定預設 interval
                                  const Text('新規則間隔(ms): '),
                                  SizedBox(
                                    width: 90,
                                    child: TextField(
                                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                      keyboardType: TextInputType.number,
                                      controller: TextEditingController(text: _defaultIntervalMs.toString()),
                                      onSubmitted: (v) {
                                        final ms = int.tryParse(v.trim());
                                        if (ms != null && ms > 0) setState(() => _defaultIntervalMs = ms);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _addRuleAtCurrent,
                                    icon: const Icon(Icons.add_circle_outline),
                                    label: const Text('在目前時間加入開始點'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _addStopAtCurrent,
                                    icon: const Icon(Icons.stop_circle_outlined),
                                    label: const Text('在目前時間加入停止點'),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: '上一個擷取點',
                                  icon: const Icon(Icons.skip_previous),
                                  onPressed: () {
                                    final segments = _buildSegments(videoController.value.duration);
                                    final capTimes = _plannedCaptureTimesFromSegments(segments);
                                    if (capTimes.isEmpty) return;
                                    // 往前找（略小一點避免剛好在點上也算下一個）
                                    final idx = _indexOfPrevCapture(capTimes, videoController.value.position - const Duration(milliseconds: 1));
                                    if (idx >= 0) {
                                      videoController.seekTo(capTimes[idx]);
                                      setState(() {});
                                    }
                                  },
                                ),
                                IconButton(
                                  tooltip: '下一個擷取點',
                                  icon: const Icon(Icons.skip_next),
                                  onPressed: () {
                                    final segments = _buildSegments(videoController.value.duration);
                                    final capTimes = _plannedCaptureTimesFromSegments(segments);
                                    if (capTimes.isEmpty) return;
                                    final idx = _indexOfPrevCapture(capTimes, videoController.value.position);
                                    if (idx + 1 < capTimes.length) {
                                      videoController.seekTo(capTimes[idx + 1]);
                                      setState(() {});
                                    }
                                  },
                                ),

                              ],
                            ),
                            Slider(
                              value: videoController.value.position.inMilliseconds.toDouble().clamp(
                                0.0,
                                videoController.value.duration.inMilliseconds.toDouble(),
                              ),
                              min: 0,
                              max: videoController.value.duration.inMilliseconds.toDouble(),
                              onChangeStart: (_) async {
                                _isPlayingBeforeChangeDuration = videoController.value.isPlaying;
                                await videoController.pause();
                                setState(() {});
                              },
                              onChanged: (v) {
                                setState(() {
                                  videoController.seekTo(Duration(milliseconds: v.toInt()));
                                });
                              },
                              onChangeEnd: (_) async {
                                if (_isPlayingBeforeChangeDuration) {
                                  await videoController.play();
                                }
                                setState(() {});
                              },
                            ),
                            // Padding(
                            //   padding: const EdgeInsets.symmetric(horizontal: 24),
                            //   child: Container(
                            //     // 要對準 Slider
                            //     color: Colors.grey.shade300,
                            //     width: double.infinity,
                            //     height: 20,
                            //     child: Row(children: []),
                            //   ),
                            // ),
                            // 標示條（與 Slider 對齊）
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: SizedBox(
                                height: 20,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final segments = _buildSegments(videoController.value.duration);
                                    final capTimes = _plannedCaptureTimesFromSegments(segments);

                                    double xFor(Duration t) =>
                                        (t.inMilliseconds / videoController.value.duration.inMilliseconds) * constraints.maxWidth;

                                    Future<void> _jumpToNearestCapture(Offset localPos) async {
                                      if (capTimes.isEmpty) return;
                                      final dx = localPos.dx;
                                      const tolPx = 6.0; // 點擊容忍像素
                                      Duration? target;
                                      double best = tolPx + 1;
                                      for (final t in capTimes) {
                                        final x = xFor(t);
                                        final dist = (x - dx).abs();
                                        if (dist < best) {
                                          best = dist;
                                          target = t;
                                        }
                                      }
                                      if (target != null && best <= tolPx) {
                                        await videoController.seekTo(target);
                                        setState(() {});
                                      }
                                    }

                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        CustomPaint(
                                          painter: _MarkersPainter(
                                            duration: videoController.value.duration,
                                            rules: rules,
                                            stops: stopPoints,
                                            captureTimes: capTimes, // <== 傳入擷取點
                                          ),
                                        ),
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapDown: (d) => _jumpToNearestCapture(d.localPosition),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),

                            // 規則調整清單（可調整每個 interval / 刪除）
                            const Text('擷取規則', style: TextStyle(fontWeight: FontWeight.bold)),
                            ListView.builder(
                              itemCount: rules.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, i) {
                                final r = rules[i];
                                // 即時計算這條規則的 end（顯示用）
                                final seg = _buildSegments(
                                  videoController.value.duration,
                                ).firstWhere((s) => s.rule.start == r.start, orElse: () => _Segment(rule: r));
                                final showEnd = seg.rule.end;
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.play_circle, color: Colors.green),
                                  title: Text(
                                    'Start ${_durationText(r.start)} → End ${showEnd != null ? _durationText(showEnd) : '依自動計算'}',
                                  ),
                                  subtitle: Row(
                                    children: [
                                      const Text('間隔(ms): '),
                                      SizedBox(
                                        width: 100,
                                        child: TextFormField(
                                          initialValue: r.interval.inMilliseconds.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(isDense: true),
                                          onChanged: (v) {
                                            final ms = int.tryParse(v.trim());
                                            if (ms != null && ms > 0) {
                                              setState(() {
                                                rules[i] = r.copyWith(interval: Duration(milliseconds: ms));
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _removeRule(i)),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            const Text('停止點', style: TextStyle(fontWeight: FontWeight.bold)),
                            ListView.builder(
                              itemCount: stopPoints.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, i) {
                                final s = stopPoints[i];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.stop_circle, color: Colors.red),
                                  title: Text('Stop @ ${_durationText(s)}'),
                                  trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _removeStop(i)),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    Row(),
                    Row(
                      children: [
                        Text('Volume'),
                        // slider
                        Expanded(
                          child: Slider(
                            value: videoController.value.volume,
                            onChanged: (value) {
                              videoController.setVolume(value);
                              setState(() {});
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            videoController.setVolume(videoController.value.volume > 0 ? 0 : 1);
                            setState(() {});
                          },
                          icon: Icon(
                            videoController.value.volume == 0 ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                  Text('個人常用設定'),
                  if (videoController != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              rectVideoPx = Rect.fromLTWH(0, 155, 1920, 260);
                              // dragStartVideoPx;
                            });
                          },
                          child: Text('設定擷取範圍'),
                        ),
                        // 微調時間
                        ...[-1, 1]
                            .map(
                              (sign) => [1000, 500, 300, 100, 50, 10, 1].map(
                                (ms) => ElevatedButton(
                                  onPressed: () {
                                    var start = videoController.value.position;
                                    start += Duration(milliseconds: sign * ms);
                                    videoController.seekTo(start);
                                    setState(() {});
                                  },
                                  child: Text('${sign < 0 ? '-' : '+'}$ms ms'),
                                ),
                              ),
                            )
                            .expand((e) => e),
                      ],
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 300,
            child: Container(
              color: Colors.black,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _logs.length,
                reverse: true,
                itemBuilder: (context, index) {
                  return Text(
                    _logs[index],
                    style: const TextStyle(color: Colors.greenAccent, fontFamily: "monospace", fontSize: 12),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ValueObject<T> {
  ValueObject(this.value);

  final T? value;
}

class _MarkersPainter extends CustomPainter {
  final Duration duration;
  final List<CaptureRule> rules;
  final List<Duration> stops;
  final List<Duration> captureTimes;

  _MarkersPainter({required this.duration, required this.rules, required this.stops, required this.captureTimes});

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = Colors.grey.shade300;
    final startPaint = Paint()..color = Colors.green;
    final stopPaint = Paint()..color = Colors.red;
    final capPaint = Paint()..color = Colors.black87;

    // 底色（已由父容器提供灰色，可略）
    canvas.drawRect(Offset.zero & size, base);

    if (duration.inMilliseconds == 0) return;
    double xFor(Duration t) => (t.inMilliseconds / duration.inMilliseconds) * size.width;

    // 先畫擷取點（每個 interval）
    for (final t in captureTimes) {
      final x = xFor(t).clamp(0.0, size.width);
      // 細小刻度
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, size.height / 2), width: 2, height: size.height),
        capPaint,
      );
    }

    // 畫開始點（規則）
    final sortedRules = [...rules]..sort((a, b) => a.start.compareTo(b.start));
    for (int i = 0; i < sortedRules.length; i++) {
      final r = sortedRules[i];
      final x = xFor(r.start).clamp(0.0, size.width);
      final line = Offset(x, 0);
      canvas.drawRect(Rect.fromCenter(center: Offset(x, size.height / 2), width: 4, height: size.height), startPaint);
      _drawLabel(canvas, Offset(x + 3, 2), 'R${i + 1}');
    }

    // 畫停止點
    final sortedStops = [...stops]..sort((a, b) => a.compareTo(b));
    for (final s in sortedStops) {
      final x = xFor(s).clamp(0.0, size.width);
      canvas.drawRect(Rect.fromCenter(center: Offset(x, size.height / 2), width: 4, height: size.height), stopPaint);
      _drawLabel(canvas, Offset(x + 3, 2), 'Stop');
    }
  }

  void _drawLabel(Canvas canvas, Offset pos, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: Colors.black87),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 80);
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _MarkersPainter old) {
    return old.duration != duration || old.rules != rules || old.stops != stops ||
        old.captureTimes != captureTimes;
  }
}

class _Segment {
  final CaptureRule rule; // 其 end 已被填好
  _Segment({required this.rule});
}
