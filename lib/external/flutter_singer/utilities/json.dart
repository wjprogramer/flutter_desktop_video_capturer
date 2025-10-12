import 'formatter.dart';

/// 客製 JSON 的資料格式化
class FSJson {
  FSJson._();

  /// Format: 00:00:00.000
  static String durationToText(Duration duration) {
    return FSFormatter.durationWithHoursToMs(duration);
  }

  /// [text] format: 00:00:00.000
  static Duration? tryParseDuration(dynamic text) {
    try {
      return _parseDuration(text);
    } catch (e) {
      return null;
    }
  }

  static Duration parseDuration(String value) {
    return _parseDuration(value)!;
  }

  static Duration? _parseDuration(dynamic text) {
    if (text is! String) {
      return null;
    }

    List<String> parts = text.split(':');
    if (parts.length == 3) {
      List<String> secondsParts = parts[2].split('.');
      if (secondsParts.length == 2) {
        return Duration(
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
          seconds: int.parse(secondsParts[0]),
          milliseconds: int.parse(secondsParts[1]),
        );
      }
    }
    return null;
  }
}
