import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/models/range.dart';

class TuningForkBaseConfigs {
  final double minFrequency = 60;
  final double maxFrequency = 3000;

  late final Range<double> frequencyRange = Range(
    lower: minFrequency,
    upper: maxFrequency,
  );

  double clampFrequency(double frequency) {
    return frequency.clamp(minFrequency, maxFrequency);
  }

  bool isFrequencyValid(double frequency) {
    return frequency >= minFrequency && frequency <= maxFrequency;
  }
}
