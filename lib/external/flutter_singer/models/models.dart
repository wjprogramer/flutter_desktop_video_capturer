import 'package:flutter_desktop_video_capturer/external/flutter_singer/utilities/json.dart';

class LyricsLine {
  LyricsLine({required this.startTime, required this.endTime, required this.content, required this.translation});

  factory LyricsLine.fromJson(Map<String, dynamic> json) {
    final rawTranslation = json['translation'] as Map<String, dynamic>;

    return LyricsLine(
      content: json['content'],
      startTime: FSJson.parseDuration(json['start_time']),
      endTime: FSJson.parseDuration(json['end_time']),
      translation: rawTranslation.map((key, value) {
        return MapEntry(key, value as String);
      }),
    );
  }

  final String content;
  final Duration startTime;
  final Duration endTime;
  final Map<String, String> translation;

  Map<String, dynamic> toJson() {
    return {
      'start_time': FSJson.durationToText(startTime),
      'end_time': FSJson.durationToText(endTime),
      'content': content,
      'translation': translation,
    };
  }
}
