import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bot_toast/bot_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LoadedImage {
  final String path;
  final ui.Image image;

  LoadedImage(this.path, this.image);
}

class Segment {
  double startX; // global X (in image pixels)
  double endX; // global X (in image pixels)
  bool keep;

  Segment(this.startX, this.endX, this.keep);

  double get width => endX - startX;
}

class PanoramaCutterPage extends StatefulWidget {
  const PanoramaCutterPage({super.key});

  @override
  State<PanoramaCutterPage> createState() => _PanoramaCutterPageState();
}

class _PanoramaCutterPageState extends State<PanoramaCutterPage> {
  List<LoadedImage> images = [];
  double imgW = 0;
  double imgH = 0;

  // Cut positions expressed in global X (pixels); includes 0 and totalWidth.
  // Invariant: sorted strictly increasing, within [0, totalWidth].
  final List<double> cuts = [];
  final List<Segment> segments = [];

  // View state
  double scale = 0.25; // preview scale
  final ScrollController hScroll = ScrollController();
  double mouseXPreview = 0; // for tooltip

  double get totalWidth => (images.isEmpty ? 0 : images.length * imgW);

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      // Sort by file name
      final files = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

      final List<LoadedImage> loaded = [];
      ui.Image? first;

      for (final file in files) {
        final bytes = await file.readAsBytes();
        final img = await decodeImageFromList(bytes);
        if (first == null) {
          first = img;
        } else {
          if (img.width != first.width || img.height != first.height) {
            BotToast.showText(text: '所有圖片尺寸必須相同，${p.basename(file.path)} 尺寸不符');
            return;
          }
        }
        loaded.add(LoadedImage(file.path, img));
      }

      setState(() {
        images = loaded;
        if (images.isNotEmpty) {
          imgW = images.first.image.width.toDouble();
          imgH = images.first.image.height.toDouble();
        } else {
          imgW = 0;
          imgH = 0;
        }
        _resetCuts();
      });
    } catch (e) {
      BotToast.showText(text: '載入失敗: $e');
    }
  }

  void _resetCuts() {
    cuts
      ..clear()
      ..add(0)
      ..add(totalWidth);
    _rebuildSegments(preserveKeeps: false);
  }

  void _rebuildSegments({bool preserveKeeps = true}) {
    final oldSegments = List<Segment>.from(segments);
    segments.clear();
    cuts.sort();
    for (int i = 0; i < cuts.length - 1; i++) {
      final start = cuts[i];
      final end = cuts[i + 1];
      bool keep = true;
      if (preserveKeeps && oldSegments.isNotEmpty) {
        final mid = (start + end) / 2.0;
        for (final o in oldSegments) {
          if (mid >= o.startX && mid < o.endX) {
            keep = o.keep;
            break;
          }
        }
      }
      segments.add(Segment(start, end, keep));
    }
    setState(() {});
  }

  void _addCutAt(double globalX) {
    // snap to pixel boundaries & avoid duplicates near existing cuts
    globalX = globalX.clamp(0, totalWidth);
    const eps = 0.5; // half pixel tolerance
    for (final c in cuts) {
      if ((c - globalX).abs() <= eps) return; // near existing
    }
    cuts.add(globalX);
    _rebuildSegments();
  }

  void _removeCutNear(double globalX) {
    if (cuts.length <= 2) return; // keep boundaries
    const pick = 8.0; // pick radius in preview pixels after scale applied
    double bestD = double.infinity;
    int bestIdx = -1;
    for (int i = 1; i < cuts.length - 1; i++) {
      // interior only
      final c = cuts[i];
      final d = (c - globalX).abs();
      if (d < bestD) {
        bestD = d;
        bestIdx = i;
      }
    }
    if (bestIdx != -1 && bestD <= pick / scale) {
      cuts.removeAt(bestIdx);
      _rebuildSegments();
    }
  }

  void _toggleSegmentAt(double globalX) {
    for (final seg in segments) {
      if (globalX >= seg.startX && globalX < seg.endX) {
        seg.keep = !seg.keep;
        setState(() {});
        return;
      }
    }
  }

  Future<void> _exportImage() async {
    if (images.isEmpty) {
      BotToast.showText(text: '尚未載入圖片');
      return;
    }

    final kept = segments.where((s) => s.keep && s.width > 0).toList();
    if (kept.isEmpty) {
      BotToast.showText(text: '沒有保留的片段');
      return;
    }

    final outWidth = kept.fold<double>(0, (w, s) => w + s.width);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    double dx = 0;
    for (final seg in kept) {
      // Draw the segment, which may cross multiple source images
      double start = seg.startX;
      double remaining = seg.width;
      while (remaining > 0.0) {
        final idx = (start / imgW).floor().clamp(0, images.length - 1);
        final img = images[idx].image;
        final imgStartX = idx * imgW;
        final localX = start - imgStartX; // within this image
        final take = math.min(remaining, imgW - localX);

        final src = Rect.fromLTWH(localX, 0, take, imgH);
        final dst = Rect.fromLTWH(dx, 0, take, imgH);
        canvas.drawImageRect(img, src, dst, paint);

        start += take;
        dx += take;
        remaining -= take;
      }
    }

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(outWidth.round(), imgH.round());
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      BotToast.showText(text: '輸出失敗');
      return;
    }
    final bytes = byteData.buffer.asUint8List();

    final outDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outPath = p.join(outDir.path, 'panorama_${ts}.png');
    final outFile = File(outPath);
    await outFile.writeAsBytes(bytes);

    if (mounted) {
      BotToast.showText(text: '已匯出：$outPath');
    }
  }

  Future<void> _exportSegments() async {
    if (images.isEmpty) {
      BotToast.showText(text: '尚未載入圖片');
      return;
    }
    final kept = segments.where((s) => s.keep && s.width > 0).toList();
    if (kept.isEmpty) {
      BotToast.showText(text: '沒有保留的片段');
      return;
    }

    final outDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;

    int index = 0;
    for (final seg in kept) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();

      double start = seg.startX;
      double remaining = seg.width;
      double dx = 0;
      while (remaining > 0.0) {
        final idx = (start / imgW).floor().clamp(0, images.length - 1);
        final img = images[idx].image;
        final imgStartX = idx * imgW;
        final localX = start - imgStartX;
        final take = math.min(remaining, imgW - localX);

        final src = Rect.fromLTWH(localX, 0, take, imgH);
        final dst = Rect.fromLTWH(dx, 0, take, imgH);
        canvas.drawImageRect(img, src, dst, paint);

        start += take;
        dx += take;
        remaining -= take;
      }

      final picture = recorder.endRecording();
      final uiImage = await picture.toImage(seg.width.round(), imgH.round());
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        BotToast.showText(text: '輸出失敗');
        return;
      }
      final bytes = byteData.buffer.asUint8List();

      final outDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outPath = p.join(outDir.path, 'panorama_$index.png');
      final outFile = File(outPath);
      await outFile.writeAsBytes(bytes);
      index++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = images.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panorama Cutter (Windows / macOS)'),
        actions: [
          IconButton(tooltip: '開啟圖片', onPressed: _pickImages, icon: const Icon(Icons.folder_open)),
          const SizedBox(width: 8),
          IconButton(tooltip: '重置切割點', onPressed: canEdit ? _resetCuts : null, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '匯出 (產生新圖)',
            onPressed: canEdit ? _exportSegments : null, // _exportImage
            icon: const Icon(Icons.download),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _Toolbar(
            canEdit: canEdit,
            scale: scale,
            onScaleChanged: (v) => setState(() => scale = v),
            totalWidth: totalWidth,
            imgW: imgW,
            imgH: imgH,
            segments: segments,
          ),
          const Divider(height: 1),
          Expanded(
            child: images.isEmpty
                ? const Center(child: Text('請先以檔名排序選取多張尺寸相同的圖片 (水平接續)'))
                : MouseRegion(
                    onHover: (e) {
                      final pos = _previewToGlobalX(e.localPosition.dx);
                      setState(() => mouseXPreview = pos);
                    },
                    child: ScrollConfiguration(
                      behavior: const _NoGlowBehavior(),
                      child: SingleChildScrollView(
                        controller: hScroll,
                        scrollDirection: Axis.horizontal,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) {
                            if (!canEdit) return;
                            final gx = _previewToGlobalX(d.localPosition.dx);
                            // if (d.kind == PointerDeviceKind.mouse &&
                            //     (d.buttons & kSecondaryMouseButton) != 0) {
                            //   // right click -> remove cut near
                            //   _removeCutNear(gx);
                            // } else
                            if (HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                                HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight)) {
                              _toggleSegmentAt(gx);
                            } else {
                              _addCutAt(gx);
                            }
                          },
                          onSecondaryTapUp: (d) {
                            if (!canEdit) return;
                            final gx = _previewToGlobalX(d.localPosition.dx);
                            _removeCutNear(gx);
                          },
                          child: CustomPaint(
                            size: Size(totalWidth * scale, imgH * scale + 40),
                            painter: _PanoramaPainter(
                              images: images,
                              imgW: imgW,
                              imgH: imgH,
                              scale: scale,
                              cuts: cuts,
                              segments: segments,
                              mouseX: mouseXPreview,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  double _previewToGlobalX(double previewDx) {
    return (previewDx / scale).clamp(0, totalWidth);
  }
}

class _Toolbar extends StatelessWidget {
  final bool canEdit;
  final double scale;
  final ValueChanged<double> onScaleChanged;
  final double totalWidth;
  final double imgW;
  final double imgH;
  final List<Segment> segments;

  const _Toolbar({
    required this.canEdit,
    required this.scale,
    required this.onScaleChanged,
    required this.totalWidth,
    required this.imgW,
    required this.imgH,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('縮放：'),
          SizedBox(
            width: 200,
            child: Slider(
              value: scale,
              min: 0.05,
              max: 1.0,
              divisions: 19,
              label: '${(scale * 100).round()}%',
              onChanged: onScaleChanged,
            ),
          ),
          const SizedBox(width: 12),
          Text('尺寸：${imgW.round()} × ${imgH.round()}'),
          const SizedBox(width: 12),
          Text('圖片數量：${(totalWidth == 0 ? 0 : (totalWidth / (imgW == 0 ? 1 : imgW)).round())}'),
          const SizedBox(width: 24),
          if (canEdit)
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const _Legend(color: Colors.red, label: '切割點'),
                  const _Legend(color: Colors.black54, label: '刪除區塊網底'),
                  const Text('左鍵：新增切割 ／ 右鍵：刪除最近切割 ／ Shift+點擊：保留/刪除切換'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, color: color.withOpacity(0.5)),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _PanoramaPainter extends CustomPainter {
  final List<LoadedImage> images;
  final double imgW;
  final double imgH;
  final double scale;
  final List<double> cuts;
  final List<Segment> segments;
  final double mouseX;

  _PanoramaPainter({
    required this.images,
    required this.imgW,
    required this.imgH,
    required this.scale,
    required this.cuts,
    required this.segments,
    required this.mouseX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Background
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F7F7));

    // Draw stitched preview
    double dx = 0;
    for (final item in images) {
      final src = Rect.fromLTWH(0, 0, imgW, imgH);
      final dst = Rect.fromLTWH(dx * scale, 0, imgW * scale, imgH * scale);
      canvas.drawImageRect(item.image, src, dst, paint);
      dx += imgW;
    }

    // Overlay deleted segments
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (!seg.keep) {
        final r = Rect.fromLTWH(seg.startX * scale, 0, seg.width * scale, imgH * scale);
        canvas.drawRect(
          r,
          Paint()
            ..color = Colors.black.withOpacity(0.7)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // Draw cuts
    final cutPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = math.max(1, 2 * scale);

    for (final c in cuts) {
      final x = c * scale;
      canvas.drawLine(Offset(x, 0), Offset(x, imgH * scale), cutPaint);
    }

    // Segment indexes & rulers
    final tp = (String s, Offset o, {Color color = Colors.black}) {
      final textPainter = TextPainter(
        text: TextSpan(
          style: TextStyle(color: color, fontSize: 12),
          text: s,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, o);
    };

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final cx = (seg.startX + seg.endX) / 2 * scale;
      tp('#$i', Offset(cx - 8, imgH * scale + 4));
    }

    // Mouse vertical helper line
    if (mouseX > 0) {
      final mx = mouseX * scale;
      canvas.drawLine(
        Offset(mx, 0),
        Offset(mx, imgH * scale),
        Paint()
          ..color = Colors.blueGrey
          ..strokeWidth = 1
          ..blendMode = BlendMode.srcOver,
      );
      tp('${mouseX.toStringAsFixed(1)} px', Offset(mx + 6, 6), color: Colors.blueGrey);
    }
  }

  @override
  bool shouldRepaint(covariant _PanoramaPainter old) {
    return old.images != images ||
        old.scale != scale ||
        old.cuts != cuts ||
        old.segments != segments ||
        old.mouseX != mouseX;
  }
}

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();

  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}
