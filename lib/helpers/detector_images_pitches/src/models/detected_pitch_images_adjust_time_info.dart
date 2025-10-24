import 'package:equatable/equatable.dart';

class DetectedPitchImagesAdjustTimeInfo extends Equatable {
  const DetectedPitchImagesAdjustTimeInfo({this.adjustDetails = const []});

  final List<AdjustTimeInfo> adjustDetails;

  DetectedPitchImagesAdjustTimeInfo copyWith({List<AdjustTimeInfo>? adjustDetails}) {
    return DetectedPitchImagesAdjustTimeInfo(adjustDetails: adjustDetails ?? this.adjustDetails);
  }

  /// 取得總調整時間
  Duration getDiffDuration(Duration startTime) {
    Duration totalDiff = Duration.zero;
    for (final detail in adjustDetails) {
      if (detail.start <= startTime) {
        totalDiff += detail.diff;
      }
    }
    return totalDiff;
  }

  /// 根據開始時間、需要調整的時間，產生一個新的實例
  DetectedPitchImagesAdjustTimeInfo cloneAndAddAdjustDetail(Duration start, Duration diff) {
    final newDetails = List<AdjustTimeInfo>.from(adjustDetails)
      ..add(AdjustTimeInfo(start: start, diff: diff));
    return DetectedPitchImagesAdjustTimeInfo(adjustDetails: newDetails);
  }

  @override
  List<Object?> get props => [adjustDetails];
}

class AdjustTimeInfo {
  AdjustTimeInfo({required this.start, required this.diff});

  /// 調整開始時間
  final Duration start;

  /// 調整時間差距，包含正負，代表往前或往後調整
  final Duration diff;
}
