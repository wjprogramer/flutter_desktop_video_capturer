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

  // For adjust
  _PitchData? _selectedPitch;

  final List<List<_PitchData>> _undoStack = [];
  final List<List<_PitchData>> _redoStack = [];

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

  void _updateNewPitchDataList() {
    const startTimeForAdjust = Duration(seconds: 31, milliseconds: 800);
    const adjustTime = Duration(milliseconds: 50);
    const sign = -1; // 1: 往後調, -1: 往前調

    final newPitchData = _pitchData.map((p) {
      if (p.start >= startTimeForAdjust) {
        final newStart = p.start + adjustTime * sign;
        final newEnd = p.end + adjustTime * sign;
        return _PitchData(pitchIndex: p.pitchIndex, start: newStart, end: newEnd);
      } else {
        return _PitchData(pitchIndex: p.pitchIndex, start: p.start, end: p.end);
      }
    }).toList();

    _pitchData = newPitchData;
    setState(() {});

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

  void _shiftFrom(Duration start, Duration delta) {
    _pushHistory();
    setState(() {
      _pitchData = _pitchData.map((p) {
        if (p.start >= start) {
          return _PitchData(pitchIndex: p.pitchIndex, start: p.start + delta, end: p.end + delta);
        }
        return p;
      }).toList();
    });
  }

  List<_PitchData> _snapshot(List<_PitchData> src) =>
      src.map((p) => _PitchData(pitchIndex: p.pitchIndex, start: p.start, end: p.end)).toList();

  void _pushHistory() {
    _undoStack.add(_snapshot(_pitchData));
    _redoStack.clear(); // 新操作發生時清空 redo
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot(_pitchData));
    _pitchData = _undoStack.removeLast();
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot(_pitchData));
    _pitchData = _redoStack.removeLast();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Combine With Lyrics Demo')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                ..._lyricsLines.mapIndexed((i, e) {
                  final pitches = _getPitchesForLine(e);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(border: Border(bottom: Divider.createBorderSide(context))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 0),
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Text((i + 1).toString()),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(e.startTime.toString(), style: TextStyle(color: Colors.orange)),
                              LyricsLineView(line: e),
                              if (pitches.isNotEmpty)
                                _PitchView(
                                  pitches: pitches,
                                  line: e,
                                  selected: _selectedPitch,
                                  onSelect: (p) {
                                    setState(() => _selectedPitch = p);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(border: Border(top: Divider.createBorderSide(context))),
            child: Wrap(
              runSpacing: 12,
              spacing: 12,
              children: [
                // Undo / Redo
                FilledButton.tonalIcon(
                  onPressed: _undoStack.isEmpty ? null : _undo,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _redoStack.isEmpty ? null : _redo,
                  icon: const Icon(Icons.redo),
                  label: const Text('Redo'),
                ),
                if (_selectedPitch == null)
                  const Text('點一下上方的 pitch bar 以選取並微調')
                else ...[
                  Text('選取起點: ${_selectedPitch!.start.inMilliseconds} ms'),
                  FilledButton(
                    onPressed: () => _shiftFrom(_selectedPitch!.start, const Duration(milliseconds: -10)),
                    child: const Text('-10ms'),
                  ),
                  FilledButton(
                    onPressed: () => _shiftFrom(_selectedPitch!.start, const Duration(milliseconds: -50)),
                    child: const Text('-50ms'),
                  ),
                  FilledButton(
                    onPressed: () => _shiftFrom(_selectedPitch!.start, const Duration(milliseconds: 10)),
                    child: const Text('+10ms'),
                  ),
                  FilledButton(
                    onPressed: () => _shiftFrom(_selectedPitch!.start, const Duration(milliseconds: 50)),
                    child: const Text('+50ms'),
                  ),
                ],
              ],
            ),
          ),
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
  const _PitchView({super.key, required this.pitches, required this.line, this.selected, this.onSelect});

  final List<_PitchData> pitches;
  final LyricsLine line;
  final _PitchData? selected;
  final ValueChanged<_PitchData>? onSelect;

  @override
  Widget build(BuildContext context) {
    final totalMs = line.endTime.inMilliseconds - line.startTime.inMilliseconds;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final size = box.size;
        final local = details.localPosition;

        // 命中測試：把點擊的 x 轉回 line 內的時間點，y 逼近 bar 的水平線
        final tMs = (local.dx / size.width) * totalMs;
        final t = line.startTime + Duration(milliseconds: tMs.clamp(0, totalMs).round());

        _PitchData? hit;
        for (final p in pitches) {
          if (t >= p.start && t <= p.end) {
            // 再用 y 距離過濾一下（±10px）
            final y = size.height * (1 - (p.pitchIndex / 100.0));
            if ((local.dy - y).abs() <= 10) {
              hit = p;
              break;
            }
          }
        }
        if (hit != null && onSelect != null) onSelect!(hit);
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.blue.shade50),
            width: double.infinity,
            child: SizedBox(
              height: 100,
              child: CustomPaint(painter: _PitchPainter(pitches, totalMs, line.startTime, selected: selected)),
            ),
          ),
          if (pitches.isNotEmpty)
            Positioned(
              left: 0,
              top: 0,
              child: Text(pitches.first.start.toString(), style: TextStyle(color: Colors.grey.shade400)),
            ),
        ],
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  _PitchPainter(this.pitches, this.totalMs, this.offset, {this.selected});

  final List<_PitchData> pitches;
  final int totalMs;
  final Duration offset;
  final _PitchData? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 3;

    final selPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 5;

    final pitchTextStyle = const TextStyle(color: Color(0xFF2E8BFF), fontSize: 15);
    final durationTextStyle = const TextStyle(color: Colors.black, fontSize: 10);

    for (final p in pitches) {
      final start = (p.start - offset).inMilliseconds / totalMs * size.width;
      final end = (p.end - offset).inMilliseconds / totalMs * size.width;
      final y = size.height * (1 - (p.pitchIndex / 100.0)); // pitch 越高越上

      final usePaint = (selected != null && identical(p, selected)) ? selPaint : paint;
      canvas.drawLine(Offset(start, y), Offset(end, y), usePaint);

      final tp = TextPainter(
        text: TextSpan(text: p.pitchIndex.toString(), style: pitchTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(start, y - 26));

      var millsSecondsForCalc = p.start.inMilliseconds;
      final minutes = millsSecondsForCalc ~/ 60000;
      final seconds = millsSecondsForCalc % 60000 ~/ 1000;
      final minText = minutes.toString().padLeft(2, '0');
      final secondsText = seconds.toString().padLeft(2, '0');
      final tp2 = TextPainter(
        text: TextSpan(text: '$minText:$secondsText', style: durationTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp2.paint(canvas, Offset(start, y - 40));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
