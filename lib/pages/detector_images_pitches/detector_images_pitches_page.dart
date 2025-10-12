import 'dart:convert';
import 'dart:io';

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
  String? inputDir;
  String outputFile = '';
  bool running = false;
  String log = '';

  void _append(String s) => setState(() => log += s + '\n');

  Future<void> _pickFolder() async {
    final res = await FilePicker.platform.getDirectoryPath();
    if (res != null) setState(() => inputDir = res);
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
    if (inputDir == null || inputDir!.isEmpty) {
      _append('請先選擇輸入資料夾');
      return;
    }
    if (outputFile.isEmpty) {
      _append('請先選擇輸出 JSON 路徑');
      return;
    }

    setState(() => running = true);
    final dir = Directory(inputDir!);
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => ['.png', '.jpg', '.jpeg'].contains(p.extension(f.path).toLowerCase()))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final results = <Map<String, dynamic>>[];
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
        results.add(r.toJson());
      } catch (e) {
        _append('  失敗: $e');
      }
    }

    await File(outputFile).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    _append('完成，已輸出到: $outputFile');
    setState(() => running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blue Bar Detector (Windows)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(inputDir ?? '未選擇輸入資料夾')),
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
            FilledButton.icon(
              onPressed: running ? null : _run,
              icon: running ? const CircularProgressIndicator() : const Icon(Icons.play_arrow),
              label: const Text('開始批量處理'),
            ),
            const SizedBox(height: 12),
            const Text('Log:'),
            const SizedBox(height: 8),
            Expanded(
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
          ],
        ),
      ),
    );
  }
}
