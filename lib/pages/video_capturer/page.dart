import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/capture_segment.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/models.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/video_capturer.dart';
import 'package:flutter_desktop_video_capturer/utils/toast.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'other.dart';

class CapturerPage extends StatefulWidget {
  const CapturerPage({super.key});

  @override
  State<CapturerPage> createState() => _CapturerPageState();
}

class _CapturerPageState extends State<CapturerPage> {
  final _scrollController = ScrollController();

  final List<String> _logs = [];

  final _videoCapturer = VideoCapturer();

  VideoPlayerController? _controller;

  String? get _videoPath => _videoCapturer.videoPath;

  Rect? get _rectVideoPx => _videoCapturer.rectVideoPx;

  List<CaptureRule> get _rules => _videoCapturer.rules;

  List<Duration> get _stopPoints => _videoCapturer.stopPoints;

  int get _defaultIntervalMs => _videoCapturer.defaultIntervalMs;

  Offset? _dragStartVideoPx;

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

  Future<void> _pickVideo() async {
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
    final videoSizePx = Size(vs.width.roundToDouble(), vs.height.roundToDouble());
    _dragStartVideoPx = null;

    c.play();

    _videoCapturer.setVideoPath(filePath, videoSizePx);
    setState(() {});
  }

  Offset? _screenToVideo(Offset p, Size paintSize) {
    return _videoCapturer.screenToVideo(p, paintSize);
  }

  Rect _videoRectToScreen(Rect rVideo, Size paintSize) {
    return _videoCapturer.videoRectToScreen(rVideo, paintSize);
  }

  void _onPanStart(DragStartDetails d, Size paintSize) {
    final v = _screenToVideo(d.localPosition, paintSize);
    if (v == null) return;
    _dragStartVideoPx = v;
    _videoCapturer.setRectVideoPx(null);
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d, Size paintSize) {
    if (_dragStartVideoPx == null) return;
    final v = _screenToVideo(d.localPosition, paintSize);
    if (v == null) return;
    _videoCapturer.setRectVideoPx(Rect.fromPoints(_dragStartVideoPx!, v));
    setState(() {});
  }

  void _onPanEnd() {
    setState(() {
      _dragStartVideoPx = null; // 結束拖曳，保留 rectVideoPx
    });
    if (_rectVideoPx != null) {
      final r = _rectVideoPx!;
      debugPrint(
        '選取(影片像素): x=${r.left.toStringAsFixed(1)}, y=${r.top.toStringAsFixed(1)}, '
        'w=${r.width.toStringAsFixed(1)}, h=${r.height.toStringAsFixed(1)}',
      );
    }
  }

  // === 規則 / 停止點 ===
  void _addRuleAtCurrent() {
    final c = _controller;
    if (c == null || _rectVideoPx == null) return;
    final now = c.value.position;
    _videoCapturer.addRuleAt(now);
    setState(() {});
  }

  void _addStopAtCurrent() {
    final c = _controller;
    if (c == null) return;
    final now = c.value.position;
    _videoCapturer.addStopAt(now);
    setState(() {});
  }

  void _removeRule(int index) {
    _videoCapturer.removeRuleAt(index);
    setState(() {});
  }

  void _removeStop(int index) {
    _videoCapturer.removeStopAt(index);
    setState(() {});
  }

  List<CaptureSegment> _buildSegments(Duration videoDuration) {
    return _videoCapturer.buildSegments(videoDuration);
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

  List<Duration> _plannedCaptureTimesFromSegments(List<CaptureSegment> segs) {
    return _videoCapturer.plannedCaptureTimesFromSegments(segs);
  }

  int _indexOfPrevCapture(List<Duration> times, Duration pos) {
    return _videoCapturer.indexOfPrevCapture(times, pos);
  }

  // 是否在 a 與 b 之間有停止點（嚴格介於之間；端點不算）
  bool _hasStopBetween(Duration a, Duration b) {
    if (_stopPoints.isEmpty) return false;
    final lo = a <= b ? a : b;
    final hi = a <= b ? b : a;
    for (final s in _stopPoints) {
      if (s > lo && s < hi) return true;
    }
    return false;
  }

  // 尋找「距離目前播放時間最近且中間沒有停止點」的 rule
  CaptureRule? _nearestRuleFor(Duration pos) {
    if (_rules.isEmpty) return null;
    CaptureRule? best;
    int bestAbs = 1 << 30;
    for (final r in _rules) {
      if (_hasStopBetween(r.start, pos)) continue; // 有停止點擋住則跳過
      final diff = (r.start.inMilliseconds - pos.inMilliseconds).abs();
      if (diff < bestAbs) {
        bestAbs = diff;
        best = r;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final videoController = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Video Frame Extractor'), actions: []),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  ElevatedButton(onPressed: _pickVideo, child: const Text('選擇影片')),
                  if (_videoPath != null) Text('影片: $_videoPath'),
                  const SizedBox(height: 20),
                  // ElevatedButton(onPressed: addSampleRule, child: const Text("加入範例擷取規則")),
                  // Text("目前規則數量: ${rules.length}"),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
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

                      if (_controller == null) {
                        return;
                      }

                      _videoCapturer.runCapture(
                        inputPath: _videoPath!,
                        outputDir: outputPath,
                        start: Duration.zero,
                        interval: const Duration(seconds: 1),
                        rect: _rectVideoPx!,
                        //Rect.fromLTWH(0, 0, 2160, 1440),
                        videoDuration: _controller!.value.duration,
                      );
                    },
                    child: const Text('開始擷取'),
                  ),
                  videoController == null
                      ? const Text('請先選擇影片')
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
                                            rectVideoPx: _rectVideoPx,
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
                                        if (ms == null || ms <= 0) {
                                          return;
                                        }
                                        _videoCapturer.setDefaultIntervalMs(ms);
                                        setState(() {});
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
                                    final idx = _indexOfPrevCapture(
                                      capTimes,
                                      videoController.value.position - const Duration(milliseconds: 1),
                                    );
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
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    final c = _controller;
                                    if (c == null) return;
                                    final pos = c.value.position;

                                    final nearest = _nearestRuleFor(pos);
                                    if (nearest == null) {
                                      showToast('找不到最近的開始點（中間有停止點或尚未建立規則）');
                                      return;
                                    }

                                    final ms = (pos - nearest.start).inMilliseconds.abs();
                                    if (ms <= 0) {
                                      showToast('目前時間與最近開始點相同，無法推算間隔');
                                      return;
                                    }

                                    _videoCapturer.setDefaultIntervalMs(ms);
                                    setState(() {});
                                    showToast(
                                      '已將預設間隔設為 $ms ms（最近開始點：${_durationText(nearest.start)} → 目前：${_durationText(pos)}）',
                                    );

                                    // 若你想同時把「最近那條 rule 的 interval」也一併更新，可解除下列註解：
                                    // final idx = rules.indexWhere((r) => r.start == nearest.start);
                                    // if (idx >= 0) setState(() => rules[idx] = rules[idx].copyWith(interval: Duration(milliseconds: ms)));
                                  },
                                  child: const Text('用最近開始點推算間隔'),
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
                                        (t.inMilliseconds / videoController.value.duration.inMilliseconds) *
                                        constraints.maxWidth;

                                    Future<void> jumpToNearestCapture(Offset localPos) async {
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
                                            rules: _rules,
                                            stops: _stopPoints,
                                            captureTimes: capTimes, // <== 傳入擷取點
                                          ),
                                        ),
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapDown: (d) => jumpToNearestCapture(d.localPosition),
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
                              itemCount: _rules.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, i) {
                                final r = _rules[i];
                                // 即時計算這條規則的 end（顯示用）
                                final seg = _buildSegments(
                                  videoController.value.duration,
                                ).firstWhere((s) => s.rule.start == r.start, orElse: () => CaptureSegment(rule: r));
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
                                                _rules[i] = r.copyWith(interval: Duration(milliseconds: ms));
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
                              itemCount: _stopPoints.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, i) {
                                final s = _stopPoints[i];
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
                  if (videoController != null) ...[
                    Text('個人常用設定'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _videoCapturer.setRectVideoPx(Rect.fromLTWH(0, 155, 1920, 260));
                            // dragStartVideoPx;
                            setState(() {});
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
                    Text('Debug 專用 (For 乾燥花)'),
                    Wrap(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _rules.clear();
                            _stopPoints.clear();

                            _rules.addAll([
                              CaptureRule.fromJson({
                                'start_ms': 23859,
                                'end_ms': null,
                                'interval_ms': 3322,
                                'rect': {'x': 0, 'y': 155, 'w': 1920, 'h': 260},
                              }),
                              CaptureRule.fromJson({
                                'start_ms': 119641,
                                'end_ms': null,
                                'interval_ms': 3322,
                                'rect': {'x': 0, 'y': 155, 'w': 1920, 'h': 260},
                              }),
                              CaptureRule.fromJson({
                                'start_ms': 209646,
                                'end_ms': null,
                                'interval_ms': 3322,
                                'rect': {'x': 0, 'y': 155, 'w': 1920, 'h': 260},
                              }),
                            ]);
                            _stopPoints.addAll([
                              Duration(milliseconds: 107752),
                              Duration(milliseconds: 202981),
                              Duration(milliseconds: 266308),
                            ]);

                            setState(() {});
                          },
                          child: Text('設定擷取規則和停止點'),
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
                    style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
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

class _MarkersPainter extends CustomPainter {
  _MarkersPainter({required this.duration, required this.rules, required this.stops, required this.captureTimes});

  final Duration duration;
  final List<CaptureRule> rules;
  final List<Duration> stops;
  final List<Duration> captureTimes;

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
      canvas.drawRect(Rect.fromCenter(center: Offset(x, size.height / 2), width: 2, height: size.height), capPaint);
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
    return old.duration != duration || old.rules != rules || old.stops != stops || old.captureTimes != captureTimes;
  }
}
