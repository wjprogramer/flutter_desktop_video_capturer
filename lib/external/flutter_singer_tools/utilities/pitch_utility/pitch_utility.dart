import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/models/pitch_name.dart';

import 'repositories.dart';

class PitchUtility {
  static PitchName? getPitchName(
    double frequency, {
    double tolerance = 0.1,
  }) {
    final pitchNames = PitchNamesRepository().getPitchNamesList(isDesc: false);

    // 使用 binary search 提高查找效率
    int left = 0;
    int right = pitchNames.length - 1;

    PitchName? closest;
    double minDiff = double.infinity;

    while (left <= right) {
      final mid = left + ((right - left) >> 1);
      final pitch = pitchNames[mid];

      final diff = (pitch.value - frequency).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = pitch;
      }

      if (pitch.value < frequency) {
        left = mid + 1;
      } else if (pitch.value > frequency) {
        right = mid - 1;
      } else {
        break; // 完全相等
      }
    }

    if (closest != null && (minDiff / closest.value) <= tolerance) {
      return closest;
    }

    return null; // 無符合容差範圍的音名
  }

  /// 回傳介於哪兩個 [PitchName] 之間
  ///
  /// [pitchNames] 照順序 (asc order)
  ///
  /// 如果超過 [pitchNames.last]，則回傳 (last, null)
  /// 如果低於 [pitchNames.first]，則回傳 (null, first)
  static (PitchName?, PitchName?) getBetweenNoteNames(double freq, List<PitchName> pitchNames) {
    if (pitchNames.isEmpty) return (null, null);
    if (freq < pitchNames.first.value) return (null, pitchNames.first);
    if (freq > pitchNames.last.value) return (pitchNames.last, null);

    int left = 0;
    int right = pitchNames.length - 1;

    while (left <= right) {
      final mid = left + ((right - left) >> 1);
      final midValue = pitchNames[mid].value;

      if (midValue == freq) {
        return (pitchNames[mid], pitchNames[mid]); // 完全命中
      } else if (midValue < freq) {
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    // now: right < left
    // 所以 freq 落在 pitchNames[right] 和 pitchNames[left] 之間
    return (pitchNames[right], pitchNames[left]);
  }
}
