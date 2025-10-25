import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/detector_images_pitches_provider.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/models/models.dart';
import 'package:flutter_desktop_video_capturer/models/capture_meta_file.dart';
import 'package:flutter_desktop_video_capturer/pages/detector_images_pitches/core/detector.dart';
import 'package:flutter_desktop_video_capturer/utilities/shared_preference.dart';
import 'package:flutter_desktop_video_capturer/utils/toast.dart';
import 'package:flutter_desktop_video_capturer/widgets/detector_images_pitches/image_item.dart';
import 'package:image/image.dart' as img;
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

  bool _running = false;

  bool get isDetectingImagesPitches => _running;

  /// 是否要預覽辨識結果
  bool get isPreviewImagesDetectResult => _isPreviewImagesDetectResult;

  List<File> _capturedImageFiles = [];

  /// 已擷取的圖片檔案列表
  List<File> get capturedImageFiles => _capturedImageFiles.toList();

  /// For undo adjust time info
  final List<DetectedPitchImagesAdjustTimeInfo> _adjustTimeInfosUndoStack = [];

  /// For redo adjust time info
  final List<DetectedPitchImagesAdjustTimeInfo> _adjustTimeInfosRedoStack = [];

  DetectedPitchImagesAdjustTimeInfo _adjustImageTimeInfo = DetectedPitchImagesAdjustTimeInfo();

  DetectedPitchImagesAdjustTimeInfo get adjustImageTimeInfo => _adjustImageTimeInfo;

  File? _selectedFile;

  File? get selectedImageFile => _selectedFile;

  /// Segment 是否被展開
  final Map<int, bool> _segmentExpandedState = {};

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

  Future<void> tryRunDetectImagesPitches({required String? inputDir}) async {
    if (inputDir == null || inputDir.isEmpty) {
      showToast('請先選擇輸入資料夾');
      return;
    }

    setState(() => _running = true);
    final files = getCapturedImageFiles(inputDir);

    final results = <DetectedPitchImageResult>[];
    for (final f in files) {
      print('Processing ${f.path} ...');
      try {
        final bytes = await f.readAsBytes();
        final im = img.decodeImage(bytes);
        if (im == null) {
          print('  無法解析圖片');
          continue;
        }
        final r = await processImage(p.basename(f.path), im, gridLinesYOverride: _gridLinesY);
        results.add(r);
      } catch (e) {
        print('  失敗: $e');
      }
    }

    _provider.setResult(ImagePitchDetectorResult(images: results));
    setState(() => _running = false);
  }

  List<Widget> buildDetectedPitchesImageViews({ValueChanged<FrameTimeInfo>? onPlay}) {
    final results = <Widget>[];
    int? segmentIndex;

    for (var i = 0; i < capturedImageFiles.length; i++) {
      final file = capturedImageFiles[i];
      final timeInfo = _captureMeta?.getTimeInfoByIndex(i);
      final currentSegmentIndex = _captureMeta?.getSegmentIndex(i);

      if (currentSegmentIndex != segmentIndex) {
        results.add(
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Segment ${currentSegmentIndex ?? '?'}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _segmentExpandedState[currentSegmentIndex ?? -1] =
                        !(_segmentExpandedState[currentSegmentIndex ?? -1] ?? true);
                  });
                },
                icon: Icon(
                  (_segmentExpandedState[currentSegmentIndex ?? -1] ?? true) ? Icons.expand_less : Icons.expand_more,
                ),
              ),
            ],
          ),
        );
        segmentIndex = currentSegmentIndex;
      }

      if (!(_segmentExpandedState[currentSegmentIndex ?? -1] ?? true)) {
        continue;
      }

      results.add(
        Row(
          children: [
            Text(i.toString()),
            const SizedBox(width: 8),
            Checkbox(
              value: _selectedFile == file,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedFile = file;
                  } else {
                    _selectedFile = null;
                  }
                });
              },
            ),
            Text(getStartDuration(file).toString()),
            const SizedBox(width: 8),
            if (onPlay != null && timeInfo != null)
              IconButton(onPressed: () => onPlay(timeInfo), icon: const Icon(Icons.play_arrow)),
          ],
        ),
      );

      if (timeInfo != null) {
        results.add(Text(timeInfo.startTime.toString()));
      }

      results.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ImageItem(
            provider: _provider,
            image: file,
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
                            onPressed: () => onSetGridLines(file),
                            tooltip: '使用此圖片的 Grid Lines',
                            icon: Icon(Icons.menu, color: Colors.white),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              final result = _provider.getImageResult(file);
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
                            onPressed: _provider.getSelectedBarIndexOfImage(file) == null
                                ? null
                                : () {
                                    _provider.deleteSelectedBarOfImage(file);
                                  },
                            tooltip: '刪除選取的藍條',
                            icon: Icon(
                              Icons.delete,
                              color: _provider.getSelectedBarIndexOfImage(file) == null ? Colors.grey : Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            onPressed: _provider.getSelectedBarIndexOfImage(file) == null
                                ? null
                                : () {
                                    final sel = _provider.getSelectedBarIndexOfImage(file);
                                    if (sel == null) return;
                                    _provider.copyAndPasteBarOfImage(file, sel);
                                  },
                            tooltip: '複製並貼上選取的藍條',
                            icon: Icon(
                              Icons.copy,
                              color: _provider.getSelectedBarIndexOfImage(file) == null ? Colors.grey : Colors.white,
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

  void undoAdjustTimeInfo() {
    if (_adjustTimeInfosUndoStack.isEmpty) return;
    _adjustTimeInfosRedoStack.add(_adjustImageTimeInfo);
    final previous = _adjustTimeInfosUndoStack.removeLast();
    setState(() {
      _adjustImageTimeInfo = previous;
    });
  }

  void redoAdjustTimeInfo() {
    if (_adjustTimeInfosRedoStack.isEmpty) return;
    _adjustTimeInfosUndoStack.add(_adjustImageTimeInfo);
    final next = _adjustTimeInfosRedoStack.removeLast();
    setState(() {
      _adjustImageTimeInfo = next;
    });
  }

  void _pushHistory() {
    _adjustTimeInfosUndoStack.add(_adjustImageTimeInfo);
    _adjustTimeInfosRedoStack.clear(); // 新操作發生時清空 redo
  }

  void shiftImagePitchesFrom(File file, Duration shiftDuration) {
    final index = capturedImageFiles.indexOf(file);
    if (index == -1) return;

    final imageResult = detectorImagesPitchesProvider.getImageResult(file);
    if (imageResult == null) return;

    final detectResult = detectorImagesPitchesProvider.lastResult;
    if (detectResult == null) return;

    final captureMeta = this.captureMeta;
    if (captureMeta == null) return;

    _pushHistory();

    final timeInfo = captureMeta.getTimeInfoFromZero(index);

    final newAdjustStartTime = timeInfo.startTime; //  + _adjustTimeInfo.getDiffDuration(timeInfo.startTime)
    _adjustImageTimeInfo = _adjustImageTimeInfo.cloneAndAddAdjustDetail(newAdjustStartTime, shiftDuration);

    setState(() {});
  }

  void clearAdjustTimeInfo() {
    _pushHistory();
    _adjustImageTimeInfo = DetectedPitchImagesAdjustTimeInfo();
    setState(() {});
  }

  Duration getStartDuration(File file) {
    final index = capturedImageFiles.indexOf(file);
    if (index == -1) return Duration.zero;

    final captureMeta = this.captureMeta;
    if (captureMeta == null) return Duration.zero;

    final timeInfo = captureMeta.getTimeInfoFromZero(index);
    return timeInfo.startTime + _adjustImageTimeInfo.getDiffDuration(timeInfo.startTime);
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
