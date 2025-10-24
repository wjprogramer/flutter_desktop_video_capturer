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
}