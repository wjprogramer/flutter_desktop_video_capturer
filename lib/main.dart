import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

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

class CaptureRule {
  final Duration start;
  final Duration interval;
  final Rect rect;

  CaptureRule({required this.start, required this.interval, required this.rect});

  Map<String, dynamic> toJson() => {
    "start_ms": start.inMilliseconds,
    "interval_ms": interval.inMilliseconds,
    "rect": {"x": rect.left.toInt(), "y": rect.top.toInt(), "w": rect.width.toInt(), "h": rect.height.toInt()},
  };
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scrollController = ScrollController();
  final List<String> _logs = [];
  bool _isRunning = false;

  VideoPlayerController? _controller;
  Rect? selectedRect;
  Offset? dragStart;
  Offset? dragEnd;

  String? videoPath;
  final List<CaptureRule> rules = [];

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

    final filePath = result.files.single.path!;
    _controller = VideoPlayerController.file(File(filePath))
      ..initialize().then((_) async {
        await _controller?.setVolume(0);
        setState(() {});
        _controller?.play();
      });

    setState(() {
      videoPath = filePath;
    });
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      dragStart = details.localPosition;
      dragEnd = null;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      dragEnd = details.localPosition;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (dragStart != null && dragEnd != null) {
      final rect = Rect.fromPoints(dragStart!, dragEnd!);
      setState(() {
        selectedRect = rect;
      });
      debugPrint("選取範圍: $rect");
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

    for (var rule in rules) {
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

  @override
  Widget build(BuildContext context) {
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
                      if (videoPath == null) return;

                      final outputDir = await getApplicationDocumentsDirectory();

                      runCapture(
                        inputPath: videoPath!,
                        outputDir: outputDir.path,
                        start: Duration.zero,
                        interval: const Duration(seconds: 1),
                        rect: Rect.fromLTWH(0, 0, 2160, 1440),
                      );
                    },
                    child: const Text("開始擷取"),
                  ),
                  _controller == null
                      ? const Text("請先選擇影片")
                      : Container(
                          color: Colors.black,
                          width: double.infinity,
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: Stack(
                              children: [
                                VideoPlayer(_controller!),
                                GestureDetector(
                                  onPanStart: _onPanStart,
                                  onPanUpdate: _onPanUpdate,
                                  onPanEnd: _onPanEnd,
                                  child: CustomPaint(
                                    painter: RectPainter(dragStart, dragEnd, selectedRect),
                                    child: Container(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  if (_controller != null) ...[
                    Row(
                      children: [
                        // slider
                        Expanded(
                          child: Slider(
                            value: _controller!.value.volume,
                            onChanged: (value) {
                              _controller!.setVolume(value);
                              setState(() {});
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _controller!.setVolume(_controller!.value.volume > 0 ? 0 : 1);
                            setState(() {});
                          },
                          icon: Icon(
                            _controller!.value.volume == 0 ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
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

class RectPainter extends CustomPainter {
  final Offset? start;
  final Offset? end;
  final Rect? selectedRect;

  RectPainter(this.start, this.end, this.selectedRect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final border = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (start != null && end != null) {
      final rect = Rect.fromPoints(start!, end!);
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, border);
    }

    if (selectedRect != null) {
      canvas.drawRect(selectedRect!, border);
    }
  }

  @override
  bool shouldRepaint(covariant RectPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end || oldDelegate.selectedRect != selectedRect;
  }
}
