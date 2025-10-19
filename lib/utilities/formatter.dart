class Formatter {
  Formatter._();

  /// For music duration formatting (通常不會到小時)
  static String durationText(Duration d) {
    final s = d.inSeconds;
    final m = (s / 60).floor();
    final ms = d.inMilliseconds.remainder(1000);

    final mText = m.toString().padLeft(2, '0');
    final sText = s.remainder(60).toString().padLeft(2, '0');
    final msText = ms.toString().padLeft(3, '0');

    return '$mText:$sText.$msText';
  }
}