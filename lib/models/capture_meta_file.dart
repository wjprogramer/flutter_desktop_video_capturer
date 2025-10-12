import 'package:flutter_desktop_video_capturer/page.dart';

/// 擷取影片的 metadata 檔案
class CaptureMetaFile {
  CaptureMetaFile({
    required this.videoPath,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.rules = const [],
    this.stopPoints = const [],
    this.segments = const [],
  });

  final String? videoPath;
  final int x;
  final int y;
  final int w;
  final int h;
  final List<CaptureRule> rules;
  final List<Duration> stopPoints;
  final List<CapturedSegment> segments;

  factory CaptureMetaFile.fromJson(Map<String, dynamic> json) {
    return CaptureMetaFile(
      videoPath: json["video"],
      x: json["rect"]["x"],
      y: json["rect"]["y"],
      w: json["rect"]["w"],
      h: json["rect"]["h"],
      rules: (json["rules"] as List).map((r) => CaptureRule.fromJson(r)).toList(),
      stopPoints: (json["stops_ms"] as List).map((e) => Duration(milliseconds: e)).toList(),
      segments: (json["segments"] as List).map((s) => CapturedSegment.fromJson(s)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "video": videoPath,
      "rect": {"x": x, "y": y, "w": w, "h": h},
      "rules": rules
          .map((r) => {"start_ms": r.start.inMilliseconds, "interval_ms": r.interval.inMilliseconds})
          .toList(),
      "stops_ms": stopPoints.map((e) => e.inMilliseconds).toList(),
      "segments": segments.map((s) => s.toJson()).toList(),
    };
  }
}

class CapturedSegment {
  CapturedSegment({
    required this.index,
    required this.start,
    required this.end,
    required this.interval,
    required this.outputDir,
    required this.plannedCaptureTimesMs,
  });

  final int index;
  final Duration start;
  final Duration? end;
  final Duration interval;
  final String outputDir;
  final List<int> plannedCaptureTimesMs;

  factory CapturedSegment.fromJson(Map<String, dynamic> json) {
    return CapturedSegment(
      index: json["index"],
      start: Duration(milliseconds: json["start_ms"]),
      end: json["end_ms"] != null ? Duration(milliseconds: json["end_ms"]) : null,
      interval: Duration(milliseconds: json["interval_ms"]),
      outputDir: json["output_dir"],
      plannedCaptureTimesMs: List<int>.from(json["planned_capture_times_ms"]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "index": index,
      "start_ms": start.inMilliseconds,
      "end_ms": end?.inMilliseconds,
      "interval_ms": interval.inMilliseconds,
      "output_dir": outputDir,
      "planned_capture_times_ms": plannedCaptureTimesMs,
    };
  }
}
