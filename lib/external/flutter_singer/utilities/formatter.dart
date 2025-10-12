class FSFormatter {
  FSFormatter._();

  /// Format duration to HH:mm:ss.SSS
  static String durationWithHoursToMs(Duration duration) {
    final String twoDigitMinutes = _twoDigits(duration.inMinutes.remainder(60));
    final String twoDigitSeconds = _twoDigits(duration.inSeconds.remainder(60));
    final String twoDigitMilliseconds = _threeDigits(duration.inMilliseconds.remainder(1000).toInt());

    return '${_twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds.$twoDigitMilliseconds';
  }

  /// Format duration to HH:mm:ss or mm:ss
  static String durationMedia(Duration duration) {
    final minutesText = _twoDigits(duration.inMinutes.remainder(60));
    final secondsText = _twoDigits(duration.inSeconds.remainder(60));

    // if duration is less than 1 hour, return mm:ss
    if (duration.inHours == 0) {
      return '$minutesText:$secondsText';
    }

    // if duration is more than 1 hour, return HH:mm:ss
    final hoursText = _twoDigits(duration.inHours);
    return '$hoursText:$minutesText:$secondsText';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  static String _threeDigits(int n) => n.toString().padLeft(3, '0');

}