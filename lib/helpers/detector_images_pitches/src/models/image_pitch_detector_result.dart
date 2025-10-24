import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_desktop_video_capturer/pages/detector_images_pitches/core/detector.dart';
import 'package:path/path.dart' as p;

import 'detected_pitch_image_result.dart';

class ImagePitchDetectorResult extends Equatable {
  const ImagePitchDetectorResult({required this.images});

  final List<DetectedPitchImageResult> images;

  DetectedPitchImageResult? getResult(File file) {
    try {
      return images.firstWhere((e) => e.file == p.basename(file.path));
    } catch (e) {
      return null;
    }
  }

  ImagePitchDetectorResult copyWith({List<DetectedPitchImageResult>? images}) {
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
