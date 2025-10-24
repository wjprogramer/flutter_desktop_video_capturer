import 'package:equatable/equatable.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/models/models.dart';

class DetectedPitchImageResult extends Equatable {
  const DetectedPitchImageResult({
    required this.file,
    required this.width,
    required this.height,
    required this.gridLinesY,
    required this.lineSpacingPx,
    required this.bars,
  });

  final String file;

  /// 圖片的寬度
  final int width;

  /// 圖片的高度
  final int height;

  /// 上->下 10 條灰線的 y（像素）
  final List<int> gridLinesY;
  final double lineSpacingPx;
  final List<DetectedPitch> bars;

  factory DetectedPitchImageResult.fromJson(Map<String, dynamic> json) {
    return DetectedPitchImageResult(
      file: json['file'],
      width: json['width'],
      height: json['height'],
      gridLinesY: List<int>.from(json['gridLinesY']),
      lineSpacingPx: (json['lineSpacingPx'] as num).toDouble(),
      bars: (json['bars'] as List)
          .map(
            (e) => DetectedPitch(
              xCenter: (e['x_center'] as num).toDouble(),
              x0: (e['x0'] as num).toDouble(),
              x1: (e['x1'] as num).toDouble(),
              yUnits: (e['y_line_units'] as num).toDouble(),
              yNorm: (e['y_norm_0_1'] as num).toDouble(),
              w: (e['w'] as num).toDouble(),
              h: (e['h'] as num).toDouble(),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'file': file,
    'width': width,
    'height': height,
    'gridLinesY': gridLinesY,
    'lineSpacingPx': lineSpacingPx,
    'bars': bars.map((e) => e.toJson()).toList(),
  };

  DetectedPitchImageResult copyWith({
    String? file,
    int? width,
    int? height,
    List<int>? gridLinesY,
    double? lineSpacingPx,
    List<DetectedPitch>? bars,
  }) {
    return DetectedPitchImageResult(
      file: file ?? this.file,
      width: width ?? this.width,
      height: height ?? this.height,
      gridLinesY: gridLinesY ?? this.gridLinesY,
      lineSpacingPx: lineSpacingPx ?? this.lineSpacingPx,
      bars: bars ?? this.bars,
    );
  }

  @override
  List<Object?> get props => [file, width, height, gridLinesY, lineSpacingPx, bars];
}
