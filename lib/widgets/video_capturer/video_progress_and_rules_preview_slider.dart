import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/models.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/video_capturer.dart';
import 'package:video_player/video_player.dart';

class VideoProgressAndRulesPreviewSlider extends StatefulWidget {
  const VideoProgressAndRulesPreviewSlider({super.key, required this.videoController, required this.videoCapturer});

  final VideoPlayerController videoController;

  final VideoCapturer videoCapturer;

  @override
  State<VideoProgressAndRulesPreviewSlider> createState() => _VideoProgressAndRulesPreviewSliderState();
}

class _VideoProgressAndRulesPreviewSliderState extends State<VideoProgressAndRulesPreviewSlider> {
  VideoPlayerController get videoController => widget.videoController;

  VideoCapturer get videoCapturer => widget.videoCapturer;

  var _isPlayingBeforeChangeDuration = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                final segments = videoCapturer.buildSegments(videoController.value.duration);
                final capTimes = videoCapturer.plannedCaptureTimesFromSegments(segments);

                double xFor(Duration t) =>
                    (t.inMilliseconds / videoController.value.duration.inMilliseconds) * constraints.maxWidth;

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
                        rules: videoCapturer.rules,
                        stops: videoCapturer.stopPoints,
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
        SizedBox(height: 16),
        // 微調時間
        ...[-1, 1].map((sign) {
          var options = [1000, 500, 300, 100, 50, 10, 1];
          if (sign > 0) {
            options = options.reversed.toList();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox.square(dimension: 20, child: Text(sign < 0 ? '－' : '＋')),
                ),
                SegmentedButton(
                  segments: [...options.map((ms) => ButtonSegment(value: ms, label: Text('$ms')))],
                  selected: {},
                  onSelectionChanged: (v) {
                    var start = videoController.value.position;
                    start += Duration(milliseconds: (sign * v.first).toInt());
                    videoController.seekTo(start);
                    setState(() {});
                  },
                  emptySelectionAllowed: true,
                ),
                Text('  ms'),
              ],
            ),
          );
        }),
      ],
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
      // _drawLabel(canvas, Offset(x + 3, 2), 'Stop');
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
