import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/detector_images_pitches_provider.dart';
import 'package:flutter_desktop_video_capturer/models/capture_meta_file.dart';
import 'package:flutter_desktop_video_capturer/utilities/shared_preference.dart';
import 'package:flutter_desktop_video_capturer/widgets/detector_images_pitches/image_item.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

mixin DetectorImagesPitchesViewMixin<T extends StatefulWidget> on State<T> {
  final detectorImagesPitchesProvider = DetectorImagesPitchesProvider();

  DetectorImagesPitchesProvider get _provider => detectorImagesPitchesProvider;

  CaptureMeta? _captureMeta;

  CaptureMeta? get captureMeta => _captureMeta;

  List<int> _gridLinesY = [];

  List<int> get gridLinesY => _gridLinesY;

  bool _isPreviewImagesDetectResult = true;

  /// 是否要預覽辨識結果
  bool get isPreviewImagesDetectResult => _isPreviewImagesDetectResult;

  List<File> _capturedImageFiles = [];

  /// 已擷取的圖片檔案列表
  List<File> get capturedImageFiles => _capturedImageFiles.toList();

  /// set [_captureMeta]
  void setCaptureMeta(CaptureMeta? meta) {
    _captureMeta = meta;
  }

  /// 將單一 Result 的 grid lines 設定到全域 _gridLinesY，並重新計算結果
  Future<void> onSetGridLines(File file) async {
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

  Future<void> clearGridLines() async {
    setState(() => _gridLinesY = []);
  }

  Future<void> debugSetGridLines() async {
    final gridLines = await MySharedPreference.instance.getGridLines();
    if (gridLines == null || gridLines.isEmpty) return;
    setState(() => _gridLinesY = gridLines);
  }

  void setCapturedImageFiles(List<File> files) {
    _capturedImageFiles = files.toList();
  }

  List<File> getCapturedImageFiles(String inputDir) {
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

  void togglePreviewImagesDetectResult() {
    setState(() {
      _isPreviewImagesDetectResult = !_isPreviewImagesDetectResult;
    });
  }

  List<Widget> buildDetectedPitchesImageViews() {
    final results = <Widget>[];
    int? segmentIndex;

    for (var i = 0; i < capturedImageFiles.length; i++) {
      final f = capturedImageFiles[i];
      final timeInfo = _captureMeta?.getTimeInfoByIndex(i);
      final currentSegmentIndex = _captureMeta?.getSegmentIndex(i);

      if (currentSegmentIndex != segmentIndex) {
        results.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Segment ${currentSegmentIndex ?? '?'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
        segmentIndex = currentSegmentIndex;
      }

      results.add(Text(i.toString()));

      if (timeInfo != null) {
        results.add(Text(timeInfo.startTime.toString()));
      }

      results.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ImageItem(
            provider: _provider,
            image: f,
            preview: isPreviewImagesDetectResult,
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
                            onPressed: () => onSetGridLines(f),
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
}

/// 比對兩個 List 是否內容相同（順序也要相同）
bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
