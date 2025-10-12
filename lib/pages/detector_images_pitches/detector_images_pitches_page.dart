import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_desktop_video_capturer/models/capture_meta_file.dart';
import 'package:flutter_desktop_video_capturer/utilities/shared_preference.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'core/detect_pitches_exporter.dart';
import 'core/detector.dart';
import 'provider/detector_images_pitches_provider.dart';

class DetectorImagesPitchesPage extends StatefulWidget {
  const DetectorImagesPitchesPage({super.key});

  @override
  State<DetectorImagesPitchesPage> createState() => _DetectorImagesPitchesPageState();
}

class _DetectorImagesPitchesPageState extends State<DetectorImagesPitchesPage> {
  final _provider = DetectorImagesPitchesProvider();
  String? _inputDir;
  String outputFile = '';
  bool running = false;
  String log = '';
  List<File> _inputFiles = [];
  List<int> _gridLinesY = [];
  CaptureMetaFile? _metaFile;

  /// 是否要預覽圖片
  bool _preview = true;

  void _append(String s) => setState(() => log += '$s\n');

  Future<void> _pickFolder() async {
    try {
      final inputDir = await FilePicker.platform.getDirectoryPath();
      if (inputDir == null) return;

      _inputFiles = _getImageFiles(inputDir);
      _inputDir = inputDir;
      _metaFile = await _getMeta(inputDir);
    } catch (e, s) {
      print(e);
      print(s);
      _inputDir = null;
      _inputFiles = [];
      _metaFile = null;
    } finally {
      setState(() {});
    }
  }

  Future<CaptureMetaFile> _getMeta(String inputDir) async {
    final file = File(p.join(inputDir, 'meta.json'));
    final content = await file.readAsString();
    return CaptureMetaFile.fromJson(json.decode(content));
  }

  Future<void> _pickSaveJson() async {
    final res = await FilePicker.platform.saveFile(
      dialogTitle: 'Select output JSON',
      fileName: 'out.json',
      allowedExtensions: ['json'],
      type: FileType.custom,
    );
    if (res != null) setState(() => outputFile = res);
  }

  Future<void> _run() async {
    if (_inputDir == null || _inputDir!.isEmpty) {
      _append('請先選擇輸入資料夾');
      return;
    }

    setState(() => running = true);
    final files = _getImageFiles(_inputDir!);

    final results = <ImageResult>[];
    for (final f in files) {
      _append('Processing ${f.path} ...');
      try {
        final bytes = await f.readAsBytes();
        final im = img.decodeImage(bytes);
        if (im == null) {
          _append('  無法解析圖片');
          continue;
        }
        final r = await processImage(p.basename(f.path), im, gridLinesYOverride: _gridLinesY);
        results.add(r);
      } catch (e) {
        _append('  失敗: $e');
      }
    }

    _provider.setResult(ImagePitchDetectorResult(images: results));
    setState(() => running = false);
  }

  List<File> _getImageFiles(String inputDir) {
    final dir = Directory(inputDir);
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => ['.png', '.jpg', '.jpeg'].contains(p.extension(f.path).toLowerCase()))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<void> _outputToFile() async {
    if (outputFile.isEmpty) {
      _append('請先選擇輸出 JSON 路徑');
      return;
    }
    if (_provider.lastResult == null) {
      _append('沒有可輸出的結果');
      return;
    }
    if (_metaFile == null) {
      _append('沒有可輸出的結果 (缺少 meta.json)');
      return;
    }
    final exporter = DetectPitchesExporter(
      previousStepResult: _provider.lastResult!,
      metaFile: _metaFile!,
      inputFiles: _inputFiles,
    );
    // final List<Map<String, dynamic>> jsonObjList = _provider.lastResult!.images.map((e) => e.toJson()).toList();
    // await File(outputFile).writeAsString(const JsonEncoder.withIndent('  ').convert(jsonObjList));
    await File(outputFile).writeAsString(const JsonEncoder.withIndent('  ').convert(exporter.exportToJson()));
    _append('完成，已輸出到: $outputFile');
  }

  /// 將單一 Result 的 grid lines 設定到全域 _gridLinesY，並重新計算結果
  Future<void> _onSetGridLines(File file) async {
    final result = _provider.lastResult?.getResult(file);
    if (result == null) return;

    if (_sameList(_gridLinesY, result.gridLinesY)) {
      // 沒變更就不處理
      return;
    }

    MySharedPreference.instance.setGridLines(result.gridLinesY);
    setState(() {
      _gridLinesY = result.gridLinesY;
    });
  }

  List<Widget> _buildItems() {
    final results = <Widget>[];
    int? segmentIndex;

    for (var i = 0; i < _inputFiles.length; i++) {
      final f = _inputFiles[i];
      final timeInfo = _metaFile?.getTimeInfoByIndex(i);
      final currentSegmentIndex = _metaFile?.getSegmentIndex(i);

      if (currentSegmentIndex != segmentIndex) {
        results.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Segment ${currentSegmentIndex ?? '?'}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ));
        segmentIndex = currentSegmentIndex;
      }

      results.add(Text(i.toString()));

      if (timeInfo != null) {
        results.add(Text(
          timeInfo.startTime.toString()
        ));
      }

      results.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ImageItem(
            provider: _provider,
            image: f,
            preview: _preview,
            tools: ChangeNotifierProvider.value(
              value: _provider,
              child: Builder(
                builder: (context) {
                  context.watch<DetectorImagesPitchesProvider>();
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: IntrinsicHeight(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: () => _onSetGridLines(f),
                            tooltip: '使用此圖片的 Grid Lines',
                            icon: Icon(Icons.menu, color: Colors.white),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              final result = _provider.getImageResult(f);
                              if (result == null) return;

                              print(const JsonEncoder.withIndent('  ').convert(result.toJson()));
                            },
                            tooltip: '除錯用 (Console)',
                            icon: Icon(Icons.bug_report_outlined, color: Colors.white),
                          ),
                          SizedBox(width: 8),
                          VerticalDivider(),
                          SizedBox(width: 8),
                          IconButton(
                            onPressed: _provider.getSelectedBarIndexOfImage(f) == null
                                ? null
                                : () {
                                    _provider.deleteSelectedBarOfImage(f);
                                  },
                            tooltip: '刪除選取的藍條',
                            icon: Icon(
                              Icons.delete,
                              color: _provider.getSelectedBarIndexOfImage(f) == null ? Colors.grey : Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            onPressed: _provider.getSelectedBarIndexOfImage(f) == null
                                ? null
                                : () {
                                    final sel = _provider.getSelectedBarIndexOfImage(f);
                                    if (sel == null) return;
                                    _provider.copyAndPasteBarOfImage(f, sel);
                                  },
                            tooltip: '複製並貼上選取的藍條',
                            icon: Icon(
                              Icons.copy,
                              color: _provider.getSelectedBarIndexOfImage(f) == null ? Colors.grey : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blue Bar Detector (Windows)')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_inputDir ?? '未選擇輸入資料夾')),
                    const SizedBox(width: 12),
                    FilledButton(onPressed: running ? null : _pickFolder, child: const Text('選輸入資料夾')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text(outputFile.isEmpty ? '未選擇輸出檔案' : outputFile)),
                    const SizedBox(width: 12),
                    FilledButton(onPressed: running ? null : _pickSaveJson, child: const Text('選輸出 JSON')),
                  ],
                ),
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: running ? null : _run,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('開始批量處理'),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: running ? null : _outputToFile,
                        icon: const Icon(Icons.save),
                        label: const Text('輸出到 JSON 檔案'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Grid Lines'),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _gridLinesY.isEmpty
                          ? null
                          : () async {
                              setState(() => _gridLinesY = []);
                              _run();
                            },
                      icon: const Icon(Icons.clear),
                      label: const Text('清空'),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        final gridLines = await MySharedPreference.instance.getGridLines();
                        if (gridLines == null || gridLines.isEmpty) return;
                        setState(() => _gridLinesY = gridLines);
                        await _run();
                      },
                      icon: const Icon(Icons.download),
                      label: Text('載入'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Log:'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(child: Text(log)),
                  ),
                ),
                ..._buildItems(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: () => setState(() => _preview = !_preview),
                    icon: Icon(_preview ? Icons.visibility : Icons.visibility_off),
                    label: Text(_preview ? '關閉圖片預覽' : '開啟圖片預覽'),
                  ),
                  SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      _provider.tmp();
                    },
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('暫時用'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ImagePitchDetectorResult extends Equatable {
  const ImagePitchDetectorResult({required this.images});

  final List<ImageResult> images;

  ImageResult? getResult(File file) {
    try {
      return images.firstWhere((e) => e.file == p.basename(file.path));
    } catch (e) {
      return null;
    }
  }

  ImagePitchDetectorResult copyWith({List<ImageResult>? images}) {
    return ImagePitchDetectorResult(images: images ?? this.images);
  }

  int? getImageResultIndex(File file) {
    try {
      return images.indexWhere((e) => e.file == p.basename(file.path));
    } catch (e) {
      return null;
    }
  }

  @override
  List<Object?> get props => [images];
}

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

  ImageResult? get _result => _provider.getImageResult(_image);

  List<DetectedBar> get _bars => _result?.bars ?? const [];

  int? get _sel => _provider.getSelectedBarIndexOfImage(_image);

  _DragMode? _mode;
  Offset? _dragStartCanvas;
  DetectedBar? _startBar;

  @override
  void initState() {
    super.initState();
  }

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
                                _bars[_sel!] = DetectedBar(
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
                                _bars[_sel!] = DetectedBar(
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
                                _bars[_sel!] = DetectedBar(
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
                                  : ImageItemPainter(_result!, selectedIndex: _sel, barsOverride: _bars),
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

class ImageItemPainter extends CustomPainter {
  ImageItemPainter(this.result, {this.selectedIndex, this.barsOverride});

  final ImageResult result;
  final int? selectedIndex; // 新增：目前選取哪個 bar
  final List<DetectedBar>? barsOverride; // 新增：可用外部 bar 覆寫

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
    final double avgGap = getGridLinesAvgGap(result.gridLinesY);
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
      final pitchIndex = getBarIndex(result.gridLinesY, y0, y1);
      final tp = TextPainter(
        text: TextSpan(text: pitchIndex.toString(), style: pitchTextStyle),
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

double getGridLinesAvgGap(List<int> gridLinesY) {
  if (gridLinesY.length < 2) return 1.0;
  double sum = 0;
  for (int i = 1; i < gridLinesY.length; i++) {
    sum += (gridLinesY[i] - gridLinesY[i - 1]).toDouble();
  }
  return sum / (gridLinesY.length - 1);
}

int getBarIndex(List<int> gridLinesY, double y0, double y1) {
  // 以區段的中心判斷（你保證不跨兩線，中心就足夠代表「哪邊面積多」）
  final c = (y0 + y1) / 2.0;
  if (gridLinesY.isEmpty) return 0;

  // 平均線距與半格
  final double avgGap = getGridLinesAvgGap(gridLinesY);
  final halfGap = avgGap / 2.0;

  final L = gridLinesY;
  final n = L.length;

  // ---- 底部（大於最後一條）→ 負號向下延伸：-1, -2, ...
  if (c >= L.last) {
    final d = (c - L.last);
    final halfSteps = (d / halfGap).floor();
    // 緊貼最後一條但在其下方半格 → -1
    return -(halfSteps + 1);
  }

  // ---- 頂部（小於第一條）→ 往上延伸：18, 19, 20, ...
  if (c < L.first) {
    final d = (L.first - c);
    final halfSteps = (d / halfGap).floor();
    // 內部最上段(i=0)的索引是 16/17，所以上方從 18 開始遞增
    return 2 * (n - 1) + halfSteps;
  }

  // ---- 落在相鄰兩條線中間：找 i 使得 L[i] <= c < L[i+1]
  int i = 0;
  int lo = 0, hi = n - 2;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (c < L[mid]) {
      hi = mid - 1;
    } else if (c >= L[mid + 1]) {
      lo = mid + 1;
    } else {
      i = mid;
      break;
    }
  }

  final midPt = (L[i] + L[i + 1]) / 2.0;

  // 由底往上編號：區段 (L[i], L[i+1]) 的「自底序號」s = 0 對應最底段(201~222)
  final sFromBottom = (n - 2) - i; // i=8 → s=0, i=7 → s=1, ...
  final baseEven = 2 * sFromBottom; // 底段：0/1；再上去：2/3；再上去：4/5…

  // 下半（靠近較大的 y，即較「下面」那條線）→ 偶數；上半 → 奇數
  return (c < midPt) ? (baseEven + 1) : baseEven;
}

/// 比對兩個 List 是否內容相同（順序也要相同）
bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
