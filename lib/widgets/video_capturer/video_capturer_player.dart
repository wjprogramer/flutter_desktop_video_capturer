import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/video_capturer.dart';
import 'package:video_player/video_player.dart';

class VideoCapturerPlayer extends StatefulWidget {
  const VideoCapturerPlayer({super.key, required this.videoController, required this.videoCapturer});

  final VideoPlayerController videoController;

  final VideoCapturer videoCapturer;

  @override
  State<VideoCapturerPlayer> createState() => _VideoCapturerPlayerState();
}

class _VideoCapturerPlayerState extends State<VideoCapturerPlayer> {
  VideoPlayerController get videoController => widget.videoController;

  VideoCapturer get videoCapturer => widget.videoCapturer;

  Offset? _dragStartVideoPx;

  void _onPanStart(DragStartDetails d, Size paintSize) {
    final v = videoCapturer.screenToVideo(d.localPosition, paintSize);
    if (v == null) return;
    _dragStartVideoPx = v;
    videoCapturer.setRectVideoPx(null);
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d, Size paintSize) {
    if (_dragStartVideoPx == null) return;
    final v = videoCapturer.screenToVideo(d.localPosition, paintSize);
    if (v == null) return;
    videoCapturer.setRectVideoPx(Rect.fromPoints(_dragStartVideoPx!, v));
    setState(() {});
  }

  void _onPanEnd() {
    setState(() {
      _dragStartVideoPx = null; // 結束拖曳，保留 rectVideoPx
    });
    if (videoCapturer.rectVideoPx != null) {
      final r = videoCapturer.rectVideoPx!;
      debugPrint(
        '選取(影片像素): x=${r.left.toStringAsFixed(1)}, y=${r.top.toStringAsFixed(1)}, '
        'w=${r.width.toStringAsFixed(1)}, h=${r.height.toStringAsFixed(1)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      alignment: Alignment.center,
      constraints: BoxConstraints(maxHeight: 450),
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
                      painter: _RectOnVideoPainter(
                        rectVideoPx: videoCapturer.rectVideoPx,
                        toScreen: (rv) => videoCapturer.videoRectToScreen(rv, paintSize),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RectOnVideoPainter extends CustomPainter {
  _RectOnVideoPainter({required this.rectVideoPx, required this.toScreen});

  final Rect? rectVideoPx;
  final Rect Function(Rect) toScreen;

  @override
  void paint(Canvas canvas, Size size) {
    if (rectVideoPx == null) return;
    final r = toScreen(_normalize(rectVideoPx!)); // 先正規化，確保 left<right, top<bottom

    final fill = Paint()
      ..color = Colors.red.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(r, fill);
    canvas.drawRect(r, stroke);
  }

  Rect _normalize(Rect r) {
    final left = math.min(r.left, r.right);
    final right = math.max(r.left, r.right);
    final top = math.min(r.top, r.bottom);
    final bottom = math.max(r.top, r.bottom);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldRepaint(covariant _RectOnVideoPainter oldDelegate) {
    return oldDelegate.rectVideoPx != rectVideoPx || oldDelegate.toScreen != toScreen;
  }
}
