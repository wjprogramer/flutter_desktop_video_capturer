import 'dart:io';

import 'package:flutter_desktop_video_capturer/helpers/combine_with_lyrics/src/models/pitch_data.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/models/image_pitch_detector_result.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/utils.dart';
import 'package:flutter_desktop_video_capturer/models/capture_meta_file.dart';

import 'models/detected_pitch_images_adjust_time_info.dart';

class DetectPitchesExporter {
  DetectPitchesExporter({
    required this.previousStepResult,
    required this.metaFile,
    required this.inputFiles,
    this.adjustTimeInfo,
  });

  final ImagePitchDetectorResult previousStepResult;

  final CaptureMeta metaFile;

  final List<File> inputFiles;

  final DetectedPitchImagesAdjustTimeInfo? adjustTimeInfo;

  Map<String, dynamic> exportToJson() {
    final results = exportToPitchDataList().map((e) => e.toJson()).toList();
    return {'results': results};
  }

  List<PitchData> exportToPitchDataList() {
    final results = <PitchData>[];
    final adjustTimeInfo = this.adjustTimeInfo ?? DetectedPitchImagesAdjustTimeInfo();

    for (var i = 0; i < inputFiles.length; i++) {
      final f = inputFiles[i];
      if (!f.existsSync()) {
        throw Exception('Input file does not exist: ${f.path}');
      }

      // final timeInfo = metaFile.getTimeInfoByIndex(i);
      final segmentIndex = metaFile.getSegmentIndex(i);
      if (segmentIndex == null) {
        throw Exception('Frame index out of range: $i');
      }
      final segment = metaFile.segments[segmentIndex];

      final imageResult = previousStepResult.getResult(f);
      if (imageResult == null) {
        throw Exception('No detection result for image: ${f.path}');
      }

      final imgW = imageResult.width.toDouble();
      final imgH = imageResult.height.toDouble();

      // 以最底線當 y=0 基準，由下往上換算
      final yBottom = imageResult.gridLinesY.isNotEmpty ? imageResult.gridLinesY.last.toDouble() : (imgH - 1.0);
      final spacing = imageResult.lineSpacingPx; // 灰線間距（像素）

      for (final pitchBar in imageResult.bars) {
        final b = pitchBar;

        // x0/x1 已是 0..1；換成像素
        final x0 = b.x0;
        final x1 = b.x1;

        // 由 y_units 反推像素的中心 y（y_units = (yBottom - yc) / spacing）
        final yc = yBottom - b.yUnits * spacing;

        // 高度用比例還原：h 是相對於圖片高度的比例
        final hpx = (b.h * imgH);
        final y0 = yc - hpx / 2.0;
        final y1 = yc + hpx / 2.0;

        final pitchIndex = getPitchIndex(imageResult.gridLinesY, y0, y1);

        final baseTimeBeforeAdjust = segment.interval * i + Duration(seconds: 1 * segmentIndex);
        final baseTime = baseTimeBeforeAdjust + adjustTimeInfo.getDiffDuration(baseTimeBeforeAdjust);
        final start = (baseTime.inMilliseconds + segment.interval.inMilliseconds * x0).round();
        final end = (baseTime.inMilliseconds + segment.interval.inMilliseconds * x1).round();

        final String flag;
        if (start > end) {
          flag = '(error) ';
        } else {
          flag = '';
        }

        if (flag.isNotEmpty) {
          print('${flag}start $start, end $end');
        }

        results.add(PitchData.fromJson({'pitch': pitchIndex, 'start_in_ms': start, 'end_in_ms': end}));
      }
    }
    return results;
  }
}
