import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/detector.dart';
import '../detector_images_pitches_page.dart';

class DetectorImagesPitchesProvider extends ChangeNotifier {
  ImagePitchDetectorResult? _lastResult;

  ImagePitchDetectorResult? get lastResult => _lastResult;

  /// map File.path to selected bar index
  final _selectedBarIndexOf = <String, int>{};

  void setResult(ImagePitchDetectorResult result) {
    _lastResult = result;
    notifyListeners();
  }

  ImageResult? getImageResult(File f) {
    return _lastResult?.getResult(f);
  }

  // region For single image
  void copyAndPasteBarOfImage(File f, int barIndex) {
    final imageResult = getImageResult(f);
    if (imageResult == null) {
      return;
    }
    final resultIndex = _lastResult?.getImageResultIndex(f);
    if (resultIndex == null) {
      return;
    }
    if (barIndex < 0 || barIndex >= imageResult.bars.length) {
      return;
    }
    final newBars = List<DetectedBar>.from(imageResult.bars)..add(imageResult.bars[barIndex]);
    final newResult = imageResult.copyWith(bars: newBars);
    final newImages = List<ImageResult>.from(_lastResult!.images)..[resultIndex] = newResult;
    _lastResult = _lastResult?.copyWith(images: newImages);
    notifyListeners();
  }

  void setSelectedBarIndexOfImage(File f, int? barIndex) {
    final imageResult = getImageResult(f);
    if (imageResult == null) {
      return;
    }
    if (barIndex != null && (barIndex < 0 || barIndex >= imageResult.bars.length)) {
      return;
    }
    _setBarIndexOfImage(f, barIndex);
  }

  int? getSelectedBarIndexOfImage(File f) {
    return _selectedBarIndexOf[f.path];
  }

  void deleteSelectedBarOfImage(File f) {
    final barIndex = _selectedBarIndexOf[f.path];
    if (barIndex == null) {
      return;
    }
    deleteBarOfImage(f, barIndex);
    _setBarIndexOfImage(f, null);
  }

  void deleteBarOfImage(File f, int barIndex) {
    final imageResult = getImageResult(f);
    if (imageResult == null) {
      return;
    }
    final resultIndex = _lastResult?.getImageResultIndex(f);
    if (resultIndex == null) {
      return;
    }
    final newBars = List<DetectedBar>.from(imageResult.bars)..removeAt(barIndex);
    final newResult = imageResult.copyWith(bars: newBars);
    final newImages = List<ImageResult>.from(_lastResult!.images)..[resultIndex] = newResult;
    _lastResult = _lastResult?.copyWith(images: newImages);
    notifyListeners();
  }

  void _setBarIndexOfImage(File f, int? barIndex) {
    if (barIndex == null) {
      _selectedBarIndexOf.remove(f.path);
    } else {
      _selectedBarIndexOf[f.path] = barIndex;
    }
    notifyListeners();
  }
  // endregion
}
