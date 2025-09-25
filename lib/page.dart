import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'other.dart';



class CaptureRule {
  CaptureRule({required this.start, this.end, required this.interval, required this.rect});

  final Duration start;
  final Duration? end;
  final Duration interval;
  final Rect rect;

  Map<String, dynamic> toJson() => {
    "start_ms": start.inMilliseconds,
    "end_ms": end?.inMilliseconds,
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
  final List<CaptureRule> rules = [];

  // 以「影片像素」為座標系來存
  Rect? rectVideoPx;
  Offset? dragStartVideoPx;
  Size? videoSizePx; // 例如 1920x1080

  var _isPlayingBeforeChangeDuration = false;

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

  Future<void> runCapture({
    required String inputPath,
    required String outputDir,
    required Duration start,
    required Duration interval,
    required Rect rect,
  }) async {
    if (videoPath == null || rules.isEmpty) return;
    final newRules = rules.map((e) => e.copyWith(rect: rect)).toList();

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

    final meta = <String, dynamic>{"video": videoPath, "segments": <Map<String, dynamic>>[]};
    final outputPattern = "${dir.path}${Platform.pathSeparator}frame_%04d.png";

    int segmentIndex = 0;

    for (var rule in newRules) {
      final segDir = Directory(p.join(projectDir.path, "seg_$segmentIndex"));
      if (!segDir.existsSync()) segDir.createSync();

      final crop = "crop=${rule.rect.width}:${rule.rect.height}:${rule.rect.left}:${rule.rect.top}";
      final fps = 1 / (rule.interval.inMilliseconds / 1000.0);

      final cmd =
          '-ss ${rule.start.inSeconds} -i "$videoPath" -vf "$crop,fps=$fps" "${p.join(segDir.path, "frame_%04d.png")}"';

      // ffmpeg command
      final args = ["-ss", start.inSeconds.toString(), "-i", inputPath, "-vf", "$crop,fps=$fps", outputPattern];

      print("Running ffmpeg: $cmd");

      // await FFmpegKit.execute(cmd);
      final process = await Process.start("ffmpeg", args);

      // 監聽 stdout/stderr
      process.stdout.transform(SystemEncoding().decoder).listen((data) {
        _addLog(data);
      });
      process.stderr.transform(SystemEncoding().decoder).listen((data) {
        _addLog(data);
      });

      final exitCode = await process.exitCode;
      print("ffmpeg 完成，exit code: $exitCode");

      meta["segments"].add({"rule": rule.toJson(), "output_dir": segDir.path});

      segmentIndex++;
    }

    final metaFile = File(p.join(projectDir.path, "meta.json"));
    await metaFile.writeAsString(jsonEncode(meta));
    print("Meta saved: ${metaFile.path}");
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
                      if (videoPath == null || rectVideoPx == null) return;

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
                            Row(
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
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Container(
                                // 要對準 Slider
                                color: Colors.grey.shade300,
                                width: double.infinity,
                                height: 20,
                                child: Row(children: []),
                              ),
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
