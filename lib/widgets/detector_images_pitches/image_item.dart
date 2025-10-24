import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/models/note_name.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/models/pitch_name.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/detector_images_pitches_provider.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/models/models.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/utils.dart';
import 'package:provider/provider.dart';

enum _DragMode { move, resizeLeft, resizeRight }

class ImageItem extends StatefulWidget {
  const ImageItem({super.key, required this.provider, required this.image, this.preview = true, this.tools});

  final File image;

  final bool preview;

  final Widget? tools;

  final DetectorImagesPitchesProvider provider;

  @override
  State<ImageItem> createState() => _ImageItemState();
}

class _ImageItemState extends State<ImageItem> {
  File get _image => widget.image;

  DetectorImagesPitchesProvider get _provider => widget.provider;

  DetectedPitchImageResult? get _result => _provider.getImageResult(_image);

  List<DetectedPitch> get _bars => _result?.bars ?? const [];

  int? get _sel => _provider.getSelectedBarIndexOfImage(_image);

  _DragMode? _mode;
  Offset? _dragStartCanvas;
  DetectedPitch? _startBar;

  ({double scale, double dx, double dy}) _tf(Size paintSize) {
    final imgW = (_result?.width ?? 1).toDouble();
    final imgH = (_result?.height ?? 1).toDouble();
    final scale = math.min(paintSize.width / imgW, paintSize.height / imgH);
    final dx = (paintSize.width - imgW * scale) / 2.0;
    final dy = (paintSize.height - imgH * scale) / 2.0;
    return (scale: scale, dx: dx, dy: dy);
  }

  Offset _canvasToImage(Offset p, Size paintSize) {
    final t = _tf(paintSize);
    return Offset((p.dx - t.dx) / t.scale, (p.dy - t.dy) / t.scale);
  }

  Offset _imageToCanvas(Offset p, Size paintSize) {
    final t = _tf(paintSize);
    return Offset(p.dx * t.scale + t.dx, p.dy * t.scale + t.dy);
  }

  int? _hitTestBar(Offset imgPt, {double tolPx = 6}) {
    final imgW = (_result?.width ?? 1).toDouble();
    final imgH = (_result?.height ?? 1).toDouble();
    if (_result == null) return null;

    // 取格線基準
    final yBottom = _result!.gridLinesY.isNotEmpty ? _result!.gridLinesY.last.toDouble() : (imgH - 1.0);
    final spacing = _result!.lineSpacingPx;

    for (int i = 0; i < _bars.length; i++) {
      final b = _bars[i];
      final x0 = b.x0 * imgW, x1 = b.x1 * imgW;
      final yc = yBottom - b.yUnits * spacing;
      final hpx = b.h * imgH;
      final rect = Rect.fromLTRB(x0, yc - hpx / 2, x1, yc + hpx / 2).inflate(tolPx);
      if (rect.contains(imgPt)) return i;
    }
    return null;
  }

  _DragMode? _hitWhichHandle(Offset imgPt, int idx, {double tolPx = 8}) {
    final imgW = (_result?.width ?? 1).toDouble();
    final imgH = (_result?.height ?? 1).toDouble();
    final yBottom = _result!.gridLinesY.isNotEmpty ? _result!.gridLinesY.last.toDouble() : (imgH - 1.0);
    final spacing = _result!.lineSpacingPx;

    final b = _bars[idx];
    final x0 = b.x0 * imgW, x1 = b.x1 * imgW;
    final yc = yBottom - b.yUnits * spacing;

    if ((imgPt - Offset(x0, yc)).distance <= tolPx) return _DragMode.resizeLeft;
    if ((imgPt - Offset(x1, yc)).distance <= tolPx) return _DragMode.resizeRight;
    return _DragMode.move;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Builder(
        builder: (context) {
          context.watch<DetectorImagesPitchesProvider>();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Opacity(
                    opacity: 0.5,
                    // opacity: 1,
                    child: Image.file(File(widget.image.path), fit: BoxFit.fitWidth),
                  ),
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final paintSize = Size(constraints.maxWidth, constraints.maxHeight);
                        return Focus(
                          autofocus: false,
                          onKeyEvent: (node, evt) {
                            if (_sel != null &&
                                evt is KeyDownEvent &&
                                evt.logicalKey.keyId == LogicalKeyboardKey.delete.keyId) {
                              _provider.deleteSelectedBarOfImage(widget.image);
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: GestureDetector(
                            onTapDown: (e) {
                              if (_result == null) return;
                              final imgPt = _canvasToImage(e.localPosition, paintSize);
                              final idx = _hitTestBar(imgPt);
                              _provider.setSelectedBarIndexOfImage(widget.image, idx);
                            },
                            onSecondaryTapDown: (e) {
                              _provider.deleteSelectedBarOfImage(widget.image);
                            },
                            onPanStart: (e) {
                              if (_result == null) return;
                              final imgPt = _canvasToImage(e.localPosition, paintSize);
                              final idx = _hitTestBar(imgPt);
                              if (idx == null) return;
                              _provider.setSelectedBarIndexOfImage(widget.image, idx);
                              _mode = _hitWhichHandle(imgPt, idx);
                              _dragStartCanvas = e.localPosition;
                              _startBar = _bars[idx];
                              setState(() {});
                            },
                            onPanUpdate: (e) {
                              if (_result == null || _sel == null || _mode == null || _startBar == null) return;
                              final t = _tf(paintSize);
                              final dxImg = e.delta.dx / t.scale;
                              final dyImg = e.delta.dy / t.scale;

                              final imgW = _result!.width.toDouble();
                              final imgH = _result!.height.toDouble();
                              final yBottom = _result!.gridLinesY.isNotEmpty
                                  ? _result!.gridLinesY.last.toDouble()
                                  : (imgH - 1.0);
                              final spacing = _result!.lineSpacingPx;

                              var b = _bars[_sel!];
                              if (_mode == _DragMode.move) {
                                // 平移：x0/x1 整體移動，yUnits 依 dy 換算
                                final dxn = dxImg / imgW;
                                final newX0 = (b.x0 + dxn).clamp(0.0, 1.0);
                                final newX1 = (b.x1 + dxn).clamp(0.0, 1.0);
                                final newYUnits = b.yUnits - (dyImg / spacing);
                                _bars[_sel!] = DetectedPitch(
                                  xCenter: ((newX0 + newX1) / 2).clamp(0.0, 1.0),
                                  x0: newX0,
                                  x1: newX1,
                                  yUnits: newYUnits,
                                  yNorm: (newYUnits / 9).clamp(0.0, 1.0),
                                  w: newX1 - newX0,
                                  h: b.h,
                                );
                              } else if (_mode == _DragMode.resizeLeft) {
                                final dxn = dxImg / imgW;
                                final newX0 = (b.x0 + dxn).clamp(0.0, b.x1 - 0.001);
                                _bars[_sel!] = DetectedPitch(
                                  xCenter: ((newX0 + b.x1) / 2),
                                  x0: newX0,
                                  x1: b.x1,
                                  yUnits: b.yUnits,
                                  yNorm: b.yNorm,
                                  w: (b.x1 - newX0),
                                  h: b.h,
                                );
                              } else if (_mode == _DragMode.resizeRight) {
                                final dxn = dxImg / imgW;
                                final newX1 = (b.x1 + dxn).clamp(b.x0 + 0.001, 1.0);
                                _bars[_sel!] = DetectedPitch(
                                  xCenter: ((b.x0 + newX1) / 2),
                                  x0: b.x0,
                                  x1: newX1,
                                  yUnits: b.yUnits,
                                  yNorm: b.yNorm,
                                  w: (newX1 - b.x0),
                                  h: b.h,
                                );
                              }
                              setState(() {});
                            },
                            onPanEnd: (_) {
                              _mode = null;
                              _dragStartCanvas = null;
                              _startBar = null;
                            },
                            child: CustomPaint(
                              painter: _result == null || !widget.preview
                                  ? null
                                  : _ImageItemPainter(_result!, selectedIndex: _sel, barsOverride: _bars),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (widget.tools != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black87),
                  child: widget.tools!,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ImageItemPainter extends CustomPainter {
  _ImageItemPainter(this.result, {this.selectedIndex, this.barsOverride});

  final DetectedPitchImageResult result;
  final int? selectedIndex; // 新增：目前選取哪個 bar
  final List<DetectedPitch>? barsOverride; // 新增：可用外部 bar 覆寫

  @override
  void paint(Canvas canvas, Size size) {
    final imgW = result.width.toDouble();
    final imgH = result.height.toDouble();

    if (imgW <= 0 || imgH <= 0) return;

    // 讓疊加層以 BoxFit.contain 等比縮放並置中
    final scale = math.min(size.width / imgW, size.height / imgH);
    final dx = (size.width - imgW * scale) / 2.0;
    final dy = (size.height - imgH * scale) / 2.0;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    // 畫外框（便於檢視邊界）
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / scale
      ..color = const Color(0x55FFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, imgW, imgH), borderPaint);

    // 畫 10 條灰線（用半透明白/灰；strokeWidth 用 1px 實體像素：1/scale）
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / scale
      ..color = Colors.red;
    for (final y in result.gridLinesY) {
      final yy = y.toDouble();
      canvas.drawLine(Offset(0, yy), Offset(imgW, yy), gridPaint);
    }
    final double avgGap = getPitchLinesAvgGap(result.gridLinesY);
    final lastY = result.gridLinesY.last.toDouble();
    canvas.drawLine(
      Offset(0, lastY + avgGap),
      Offset(imgW, lastY + avgGap),
      gridPaint..color = Colors.pink.withAlpha(100),
    );

    // 以最底線當 y=0 基準，由下往上換算
    final yBottom = result.gridLinesY.isNotEmpty ? result.gridLinesY.last.toDouble() : (imgH - 1.0);
    final spacing = result.lineSpacingPx; // 灰線間距（像素）

    // 畫藍條（半透明填色 + 外框）
    final barFill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x552E8BFF);
    final barStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / scale
      ..color = const Color(0xFF2E8BFF);

    // 文字（標記 y_units）
    final textStyle = const TextStyle(color: Color(0xFF2E8BFF), fontSize: 12);
    final pitchTextStyle = const TextStyle(color: Color(0xFF2E8BFF), fontSize: 24, backgroundColor: Colors.white);
    final bars = barsOverride ?? result.bars;
    final basePitchAtIndex0 = PitchName.fromNoteOctave(NoteName.gSharp, 3);

    for (int i = 0; i < bars.length; i++) {
      final b = bars[i];

      // x0/x1 已是 0..1；換成像素
      final x0 = (b.x0 * imgW);
      final x1 = (b.x1 * imgW);

      // 由 y_units 反推像素的中心 y（y_units = (yBottom - yc) / spacing）
      final yc = yBottom - b.yUnits * spacing;

      // 高度用比例還原：h 是相對於圖片高度的比例
      final hpx = (b.h * imgH);
      final y0 = yc - hpx / 2.0;
      final y1 = yc + hpx / 2.0;

      final rect = Rect.fromLTRB(x0, y0, x1, y1);
      canvas.drawRect(rect, barFill);
      canvas.drawRect(rect, barStroke);

      // 可選：畫出中心點
      canvas.drawCircle(Offset((x0 + x1) / 2.0, yc), 2.5 / scale, barStroke);

      // 可選：在框上方標記 y_line_units
      // final tp = TextPainter(
      //   text: TextSpan(text: b.yUnits.toStringAsFixed(2), style: textStyle),
      //   textDirection: TextDirection.ltr,
      // )..layout();
      // tp.paint(canvas, Offset(x0, y0 - 14 / scale));

      // 標上 index
      final pitchIndex = getPitchIndex(result.gridLinesY, y0, y1);
      final pitchName = basePitchAtIndex0.getNext(pitchIndex);
      final tp = TextPainter(
        text: TextSpan(text: pitchName.getDisplayName(), style: pitchTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x0, y0 - 18 / scale));

      // 把手
      if (selectedIndex == i) {
        final handlePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFFFFF);
        final edgeRadius = 5 / scale; // 視覺 5px
        canvas.drawCircle(Offset(x0, yc), edgeRadius, handlePaint);
        canvas.drawCircle(Offset(x1, yc), edgeRadius, handlePaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
