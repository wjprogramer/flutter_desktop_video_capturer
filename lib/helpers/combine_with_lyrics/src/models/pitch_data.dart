class PitchData {
  const PitchData({required this.pitchIndex, required this.start, required this.end});

  final int pitchIndex;
  final Duration start;
  final Duration end;

  factory PitchData.fromJson(Map<String, dynamic> json) {
    return PitchData(
      pitchIndex: json['pitch'],
      start: Duration(milliseconds: json['start_in_ms']),
      end: Duration(milliseconds: json['end_in_ms']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'pitch': pitchIndex, 'start_in_ms': start.inMilliseconds, 'end_in_ms': end.inMilliseconds};
  }

  PitchData copyWith({int? pitchIndex, Duration? start, Duration? end}) {
    return PitchData(
      pitchIndex: pitchIndex ?? this.pitchIndex,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  String toString() {
    return 'PitchData(pitchIndex: $pitchIndex, start: $start, end: $end)';
  }
}
