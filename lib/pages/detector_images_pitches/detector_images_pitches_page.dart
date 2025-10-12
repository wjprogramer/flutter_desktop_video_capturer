import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'core/detector.dart';

class DetectorImagesPitchesPage extends StatefulWidget {
  const DetectorImagesPitchesPage({super.key});

  @override
  State<DetectorImagesPitchesPage> createState() => _DetectorImagesPitchesPageState();
}

class _DetectorImagesPitchesPageState extends State<DetectorImagesPitchesPage> {
  String? _inputDir;
  String outputFile = '';
  bool running = false;
  String log = '';
  _ProcessResult? _lastResult;
  List<File> _inputFiles = [];

  /// 是否要預覽圖片
  bool _preview = true;

  void _append(String s) => setState(() => log += '$s\n');

  Future<void> _pickFolder() async {
    final inputDir = await FilePicker.platform.getDirectoryPath();
    if (inputDir == null) return;

    _inputFiles = _getImageFiles(inputDir);
    _inputDir = inputDir;

    setState(() {});
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
        final r = await processImage(p.basename(f.path), im);
        results.add(r);
      } catch (e) {
        _append('  失敗: $e');
      }
    }

    _lastResult = _ProcessResult(images: results);
    setState(() => running = false);
  }

  // get files
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
    if (_lastResult == null) {
      _append('沒有可輸出的結果');
      return;
    }
    final List<Map<String, dynamic>> jsonObjList = _lastResult!.images.map((e) => e.toJson()).toList();
    await File(outputFile).writeAsString(const JsonEncoder.withIndent('  ').convert(jsonObjList));
    _append('完成，已輸出到: $outputFile');
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
                        icon: running ? const CircularProgressIndicator() : const Icon(Icons.play_arrow),
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
                ..._inputFiles.map(
                  (f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ImageItem(image: f, result: _lastResult?.getResult(f), preview: _preview),
                  ),
                ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessResult {
  _ProcessResult({required this.images});

  final List<ImageResult> images;

  ImageResult? getResult(File file) {
    try {
      return images.firstWhere((e) => e.file == p.basename(file.path));
    } catch (e) {
      return null;
    }
  }
}

class ImageItem extends StatelessWidget {
  const ImageItem({super.key, required this.image, this.result, this.preview = true});

  final File image;

  final ImageResult? result;

  final bool preview;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Opacity(
          opacity: 0.5,
          // opacity: 1,
          child: Image.file(File(image.path), fit: BoxFit.fitWidth),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: result == null || !preview ? null : ImageItemPainter(result!),
            child: SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class ImageItemPainter extends CustomPainter {
  ImageItemPainter(this.result);

  final ImageResult result;

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

    for (final b in result.bars) {
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
      final tp = TextPainter(
        text: TextSpan(text: b.yUnits.toStringAsFixed(2), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x0, y0 - 14 / scale));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
