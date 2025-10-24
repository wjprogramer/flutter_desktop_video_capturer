import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/detect_pitches_exporter.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/detector_images_pitches_mixin.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/detector_images_pitches_provider.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/models/models.dart';
import 'package:flutter_desktop_video_capturer/models/capture_meta_file.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'core/detector.dart';

class DetectorImagesPitchesPage extends StatefulWidget {
  const DetectorImagesPitchesPage({super.key});

  @override
  State<DetectorImagesPitchesPage> createState() => _DetectorImagesPitchesPageState();
}

class _DetectorImagesPitchesPageState extends State<DetectorImagesPitchesPage> with DetectorImagesPitchesViewMixin {
  DetectorImagesPitchesProvider get _provider => detectorImagesPitchesProvider;

  List<int> get _gridLinesY => gridLinesY;

  String? _inputDir;
  String outputFile = '';
  bool running = false;
  String log = '';

  /// 已擷取的圖片檔案列表
  List<File> get _inputFiles => capturedImageFiles;

  CaptureMeta? get _metaFile => captureMeta;

  void _append(String s) => setState(() => log += '$s\n');

  Future<void> _pickFolder() async {
    try {
      final inputDir = await FilePicker.platform.getDirectoryPath();
      if (inputDir == null) return;

      setCapturedImageFiles(getCapturedImageFiles(inputDir));
      setCaptureMeta(await _getMeta(inputDir));
      _inputDir = inputDir;
    } catch (e, s) {
      print(e);
      print(s);
      _inputDir = null;
      setCapturedImageFiles([]);
      setCaptureMeta(null);
    } finally {
      setState(() {});
    }
  }

  Future<CaptureMeta> _getMeta(String inputDir) async {
    final file = File(p.join(inputDir, 'meta.json'));
    final content = await file.readAsString();
    return CaptureMeta.fromJson(json.decode(content));
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
    final files = getCapturedImageFiles(_inputDir!);

    final results = <DetectedPitchImageResult>[];
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
                              await clearGridLines();
                              _run();
                            },
                      icon: const Icon(Icons.clear),
                      label: const Text('清空'),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        await debugSetGridLines();
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
                ...buildDetectedPitchesImageViews(),
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
                    onPressed: togglePreviewImagesDetectResult,
                    icon: Icon(isPreviewImagesDetectResult ? Icons.visibility : Icons.visibility_off),
                    label: Text(isPreviewImagesDetectResult ? '關閉音階預覽' : '開啟音階預覽'),
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
