import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/demo_data/dry_flower/data.dart';
import 'package:flutter_desktop_video_capturer/demo_data/dry_flower/pitch_data.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer/models/models.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer/widgets/lyrics_line_view.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/models/note_name.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/models/pitch_name.dart';
import 'package:flutter_desktop_video_capturer/helpers/combine_with_lyrics/src/models/pitch_data.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/models/detected_pitch_image_result.dart';

mixin CombineWithLyricsViewMixin<T extends StatefulWidget> on State<T> {
  List<PitchData> _pitchData = [];

  List<PitchData> get pitchData => _pitchData;

  List<LyricsLine> _lyricsLines = [];

  List<LyricsLine> get lyricsLines => _lyricsLines;

  // For adjust
  PitchData? _selectedPitch;

  PitchData? get selectedPitch => _selectedPitch;

  final List<List<PitchData>> _undoStack = [];

  List<List<PitchData>> get undoStack => _undoStack;

  final List<List<PitchData>> _redoStack = [];

  List<List<PitchData>> get redoStack => _redoStack;

  void initCombineWithLyricsData() {
    _pitchData = demoDryFlowerPitchData.map((e) => PitchData.fromJson(e)).toList();
    _lyricsLines = (demoDryFlower['lines'] as List).map((e) => LyricsLine.fromJson(e)).toList();
  }

  void setPitchDataListByImageResults(List<DetectedPitchImageResult> results) {

  }

  void debugPrintPitchDataList() {
    print(
      pitchData.map((p) {
        return JsonEncoder().convert({
          'pitch': p.pitchIndex,
          'start_in_ms': p.start.inMilliseconds,
          'end_in_ms': p.end.inMilliseconds,
        });
      }).toList(),
    );
  }

  void shiftPitchesFrom(Duration start, Duration delta) {
    _pushHistory();

    // 先記住目前選取的 pitch（若它會被平移，記下平移後的時間）
    final sel = _selectedPitch;
    final bool selWillMove = sel != null && sel.start >= start;
    final Duration? selNewStart = selWillMove ? sel.start + delta : null;
    final Duration? selNewEnd = selWillMove ? sel.end + delta : null;

    setState(() {
      // 1) 做平移
      _pitchData = _pitchData.map((p) {
        if (p.start >= start) {
          return PitchData(pitchIndex: p.pitchIndex, start: p.start + delta, end: p.end + delta);
        }
        return p;
      }).toList();

      // 2) 若選取的那條被平移了，重新在新陣列裡指向它
      if (selWillMove && selNewStart != null && selNewEnd != null) {
        // 以 pitchIndex + start/end 完整匹配，避免誤配
        final idx = _pitchData.indexWhere(
          (p) => p.pitchIndex == sel.pitchIndex && p.start == selNewStart && p.end == selNewEnd,
        );
        if (idx != -1) {
          _selectedPitch = _pitchData[idx];
        } else {
          // 找不到就先清掉，避免指向舊物件
          _selectedPitch = null;
        }
      }
    });
  }

  void _pushHistory() {
    _undoStack.add(_snapshot(_pitchData));
    _redoStack.clear(); // 新操作發生時清空 redo
  }

  List<PitchData> _snapshot(List<PitchData> src) =>
      src.map((p) => PitchData(pitchIndex: p.pitchIndex, start: p.start, end: p.end)).toList();

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot(_pitchData));
    _pitchData = _undoStack.removeLast();
    setState(() {});
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot(_pitchData));
    _pitchData = _redoStack.removeLast();
    setState(() {});
  }

  void setSelectedPitch(PitchData? pitch) {
    setState(() {
      _selectedPitch = pitch;
    });
  }

  List<Widget> buildLyricsAndPitchChildren() {
    final results = <Widget>[];

    // Helper: 判斷 pitch 是否屬於某 line
    bool belongsToLine(PitchData p, LyricsLine line) {
      return p.start >= line.startTime && p.start < line.endTime;
    }

    // 取得所有「沒有落在任何 line 內」的 pitch
    final unassigned = _pitchData.where((p) {
      return !_lyricsLines.any((line) => belongsToLine(p, line));
    }).toList();

    // 依 start 排序，方便之後插入正確位置
    unassigned.sort((a, b) => a.start.compareTo(b.start));

    for (var i = 0; i < _lyricsLines.length; i++) {
      final line = _lyricsLines[i];
      final pitches = _getPitchesForLine(line);

      if (i == 0) {
        final before = unassigned.where((p) => p.start < line.startTime).toList();
        if (before.isNotEmpty) {
          results.add(
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(border: Border(bottom: Divider.createBorderSide(context))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔹 遺漏 Pitch（歌詞前）', style: TextStyle(color: Colors.red)),
                  _PitchView(
                    pitches: before,
                    line: LyricsLine(
                      startTime: Duration.zero,
                      endTime: line.startTime,
                      content: '',
                      translation: const {},
                    ),
                    selected: _selectedPitch,
                    onSelect: setSelectedPitch,
                  ),
                ],
              ),
            ),
          );
        }
      }

      results.add(
        Container(
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
                    Text(line.startTime.toString(), style: TextStyle(color: Colors.orange)),
                    LyricsLineView(line: line),
                    if (pitches.isNotEmpty)
                      _PitchView(pitches: pitches, line: line, selected: _selectedPitch, onSelect: setSelectedPitch),
                  ],
                ),
              ),
              SizedBox(width: 30),
            ],
          ),
        ),
      );

      final nextLine = i < _lyricsLines.length - 1 ? _lyricsLines[i + 1] : null;
      if (nextLine != null) {
        final between = unassigned.where((p) => p.start >= line.endTime && p.start < nextLine.startTime).toList();
        if (between.isNotEmpty) {
          results.add(
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
              decoration: BoxDecoration(border: Border(bottom: Divider.createBorderSide(context))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🔹 遺漏 Pitch（第 ${i + 1} 行 → 第 ${i + 2} 行）', style: const TextStyle(color: Colors.red)),
                  _PitchView(
                    pitches: between,
                    line: LyricsLine(
                      startTime: line.endTime,
                      endTime: nextLine.startTime,
                      content: '',
                      translation: const {},
                    ),
                    selected: _selectedPitch,
                    onSelect: setSelectedPitch,
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    // ---- 4️⃣ 最後一行之後的遺漏 pitch ----
    if (_lyricsLines.isNotEmpty) {
      final lastEnd = _lyricsLines.last.endTime;
      final after = unassigned.where((p) => p.start >= lastEnd).toList();
      if (after.isNotEmpty) {
        results.add(
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔹 遺漏 Pitch（歌詞結束後）', style: TextStyle(color: Colors.red)),
                _PitchView(
                  pitches: after,
                  line: LyricsLine(
                    startTime: lastEnd,
                    endTime: lastEnd + const Duration(seconds: 3),
                    content: '',
                    translation: const {},
                  ),
                  selected: _selectedPitch,
                  onSelect: setSelectedPitch,
                ),
              ],
            ),
          ),
        );
      }
    }

    return results;
  }

  List<PitchData> _getPitchesForLine(LyricsLine line) {
    return _pitchData.where((p) {
      return p.end > line.startTime && p.start < line.endTime;
    }).toList();
  }
}

class _PitchView extends StatelessWidget {
  const _PitchView({required this.pitches, required this.line, this.selected, this.onSelect});

  final List<PitchData> pitches;
  final LyricsLine line;
  final PitchData? selected;
  final ValueChanged<PitchData>? onSelect;

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

        PitchData? hit;
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

  final List<PitchData> pitches;
  final int totalMs;
  final Duration offset;
  final PitchData? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 3;

    final selPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 5;

    final pitchTextStyle = const TextStyle(color: Color(0xFF2E8BFF), fontSize: 13);
    final durationTextStyle = const TextStyle(color: Colors.black, fontSize: 10);
    final basePitchAtIndex0 = PitchName.fromNoteOctave(NoteName.gSharp, 3);

    for (final p in pitches) {
      final start = (p.start - offset).inMilliseconds / totalMs * size.width;
      final end = (p.end - offset).inMilliseconds / totalMs * size.width;
      final y = size.height * (1 - (p.pitchIndex / 100.0)); // pitch 越高越上

      final usePaint = (selected != null && identical(p, selected)) ? selPaint : paint;
      canvas.drawLine(Offset(start, y), Offset(end, y), usePaint);

      final pitchName = basePitchAtIndex0.getNext(p.pitchIndex);
      final tp = TextPainter(
        // p.pitchIndex
        text: TextSpan(text: pitchName.getDisplayName(), style: pitchTextStyle),
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
