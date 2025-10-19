import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/models/base/base.dart';
import 'package:flutter_desktop_video_capturer/pages/video_capturer/page.dart';
import 'package:flutter_desktop_video_capturer/utils/toast.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class CaptureRule {
  CaptureRule({required this.start, this.end, required this.interval, required this.rect});

  final Duration start;
  final Duration? end; // 實際運行前會依 stop/rule 自動計算
  final Duration interval;
  final Rect rect; // 影片像素座標

  factory CaptureRule.fromJson(Map<String, dynamic> json) {
    return CaptureRule(
      start: Duration(milliseconds: json['start_ms']),
      end: json['end_ms'] != null ? Duration(milliseconds: json['end_ms']) : null,
      interval: Duration(milliseconds: json['interval_ms']),
      rect: Rect.fromLTWH(
        (json['rect']['x'] as num).toDouble(),
        (json['rect']['y'] as num).toDouble(),
        (json['rect']['w'] as num).toDouble(),
        (json['rect']['h'] as num).toDouble(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'start_ms': start.inMilliseconds,
    'end_ms': end?.inMilliseconds,
    'interval_ms': interval.inMilliseconds,
    'rect': {'x': rect.left.toInt(), 'y': rect.top.toInt(), 'w': rect.width.toInt(), 'h': rect.height.toInt()},
  };

  CaptureRule copyWith({Duration? start, ValueObject<Duration>? end, Duration? interval, Rect? rect}) {
    return CaptureRule(
      start: start ?? this.start,
      end: end != null ? end.value : this.end,
      interval: interval ?? this.interval,
      rect: rect ?? this.rect,
    );
  }
}