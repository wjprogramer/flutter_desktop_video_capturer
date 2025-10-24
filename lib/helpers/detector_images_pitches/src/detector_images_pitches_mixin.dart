import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/video_capturer.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/detector_images_pitches_provider.dart';
import 'package:flutter_desktop_video_capturer/third_party/uuid/uuid.dart';
import 'package:flutter_desktop_video_capturer/utilities/file_structure_utility.dart';
import 'package:flutter_desktop_video_capturer/utilities/formatter.dart';
import 'package:flutter_desktop_video_capturer/utils/toast.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/models/note_name.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/models/pitch_name.dart';
import 'package:flutter_desktop_video_capturer/models/capture_meta_file.dart';
import 'package:flutter_desktop_video_capturer/utilities/shared_preference.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

mixin DetectorImagesPitchesViewMixin<T extends StatefulWidget> on State<T> {
  final detectorImagesPitchesProvider = DetectorImagesPitchesProvider();
  DetectorImagesPitchesProvider get _provider => detectorImagesPitchesProvider;

  CaptureMetaFile? _metaFile;
  CaptureMetaFile? get captureMetaFile => _metaFile;

  List<int> _gridLinesY = [];
  List<int> get gridLinesY => _gridLinesY;

  bool _isPreviewImagesDetectResult = true;
  /// 是否要預覽辨識結果
  bool get isPreviewImagesDetectResult => _isPreviewImagesDetectResult;

  /// set [_metaFile]
  void setCaptureMetaFile(CaptureMetaFile? metaFile) {
    setState(() {
      _metaFile = metaFile;
    });
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

  void togglePreviewImagesDetectResult() {
    setState(() {
      _isPreviewImagesDetectResult = !_isPreviewImagesDetectResult;
    });
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