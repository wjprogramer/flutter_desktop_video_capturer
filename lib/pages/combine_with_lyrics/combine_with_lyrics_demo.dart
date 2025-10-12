import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/demo_data/dry_flower/data.dart';
import 'package:flutter_desktop_video_capturer/demo_data/dry_flower/pitch_data.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer/models/models.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer/widgets/lyrics_line_view.dart';

class CombineWithLyricsDemoPage extends StatefulWidget {
  const CombineWithLyricsDemoPage({super.key});

  @override
  State<CombineWithLyricsDemoPage> createState() => _CombineWithLyricsDemoPageState();
}

class _CombineWithLyricsDemoPageState extends State<CombineWithLyricsDemoPage> {
  List<_PitchData> _pitchData = [];
  List<LyricsLine> _lyricsLines = [];

  @override
  void initState() {
    super.initState();
    _pitchData = demoDryFlowerPitchData.map((e) => _PitchData.fromJson(e)).toList();
    _lyricsLines = (demoDryFlower['lines'] as List).map((e) => LyricsLine.fromJson(e)).toList();
  }

  List<_PitchData> _getPitchesForLine(LyricsLine line) {
    return _pitchData.where((p) {
      return p.end > line.startTime && p.start < line.endTime;
    }).toList();
  }

  void _printNewPitchDataList() {
    const startTimeForAdjust = Duration(seconds: 0);
    const adjustTime = Duration(seconds: 12, milliseconds: 55); // 1.2

    final newPitchData = _pitchData.map((p) {
      if (p.start >= startTimeForAdjust) {
        return _PitchData(pitchIndex: p.pitchIndex, start: p.start + adjustTime, end: p.end + adjustTime);
      } else {
        return _PitchData(pitchIndex: p.pitchIndex, start: p.start, end: p.end);
      }
    }).toList();

    print(
      newPitchData.map((p) {
        return JsonEncoder().convert({
          'pitch': p.pitchIndex,
          'start_in_ms': p.start.inMilliseconds,
          'end_in_ms': p.end.inMilliseconds,
        });
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Combine With Lyrics Demo')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final p = demoDryFlowerPitchData.map((e) => _PitchData.fromJson(e)).toList();
          print(p.first.start);

          print(_lyricsLines.first.startTime);
          print(p.first.start - _lyricsLines.first.startTime);

          print('-----');
          _printNewPitchDataList();
        },
      ),
      body: ListView(
        children: [
          ..._lyricsLines.mapIndexed((i, e) {
            final pitches = _getPitchesForLine(e);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 40, alignment: Alignment.center, child: Text((i + 1).toString())),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LyricsLineView(line: e),
                      if (pitches.isNotEmpty) _PitchView(pitches: pitches, line: e),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _PitchData {
  const _PitchData({required this.pitchIndex, required this.start, required this.end});

  final int pitchIndex;
  final Duration start;
  final Duration end;

  factory _PitchData.fromJson(Map<String, dynamic> json) {
    return _PitchData(
      pitchIndex: json['pitch'],
      start: Duration(milliseconds: json['start_in_ms']),
      end: Duration(milliseconds: json['end_in_ms']),
    );
  }
}

class _PitchView extends StatelessWidget {
  const _PitchView({super.key, required this.pitches, required this.line});

  final List<_PitchData> pitches;
  final LyricsLine line;

  @override
  Widget build(BuildContext context) {
    final totalMs = line.endTime.inMilliseconds - line.startTime.inMilliseconds;
    return SizedBox(height: 100, child: CustomPaint(painter: _PitchPainter(pitches, totalMs, line.startTime)));
  }
}

class _PitchPainter extends CustomPainter {
  _PitchPainter(this.pitches, this.totalMs, this.offset);

  final List<_PitchData> pitches;
  final int totalMs;
  final Duration offset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 3;
    final pitchTextStyle = const TextStyle(color: Color(0xFF2E8BFF), fontSize: 20);

    for (final p in pitches) {
      final start = (p.start - offset).inMilliseconds / totalMs * size.width;
      final end = (p.end - offset).inMilliseconds / totalMs * size.width;
      final y = size.height * (1 - (p.pitchIndex / 100.0)); // pitch 越高越上
      canvas.drawLine(Offset(start, y), Offset(end, y), paint);

      final tp = TextPainter(
        text: TextSpan(text: p.pitchIndex.toString(), style: pitchTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(start, y - 18));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
