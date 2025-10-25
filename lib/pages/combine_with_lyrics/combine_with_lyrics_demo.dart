import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/demo_data/dry_flower/pitch_data.dart';
import 'package:flutter_desktop_video_capturer/env/env.dart';
import 'package:flutter_desktop_video_capturer/helpers/combine_with_lyrics/src/combine_with_lyrics_view_mixin.dart';
import 'package:flutter_desktop_video_capturer/helpers/combine_with_lyrics/src/models/pitch_data.dart';
import 'package:flutter_desktop_video_capturer/helpers/traceable_history.dart';

const minGap = Duration(milliseconds: 120); // 視情況調整閾值

class CombineWithLyricsDemoPage extends StatefulWidget {
  const CombineWithLyricsDemoPage({super.key});

  @override
  State<CombineWithLyricsDemoPage> createState() => _CombineWithLyricsDemoPageState();
}

class _CombineWithLyricsDemoPageState extends State<CombineWithLyricsDemoPage> with CombineWithLyricsViewMixin {
  final TraceableHistory<List<PitchData>> _history = TraceableHistory<List<PitchData>>();

  bool get _canUndo => _history.canUndo;

  bool get _canRedo => _history.canRedo;

  @override
  void initState() {
    super.initState();
    initCombineWithLyricsData(useDemoDryFlower: debugUseDryFlower);

    if (debugUseDryFlower) {
      final pitchData = demoDryFlowerPitchData.map((e) => PitchData.fromJson(e)).toList();
      setPitchDataList(pitchData);
    }
  }

  void _undo() {
    final curr = _history.undo();
    if (curr == null) return;
    _setPitchDataList(curr);
  }

  void _redo() {
    final curr = _history.redo();
    if (curr == null) return;
    _setPitchDataList(curr);
  }

  void _pushHistory() {
    _history.add(_snapshot(pitchData));
  }

  void _setPitchDataList(List<PitchData> pitchData) {
    _pushHistory();
    setPitchDataList(pitchData);
  }

  void _shiftPitchesFrom(Duration start, Duration delta) {
    _pushHistory();

    // 先記住目前選取的 pitch（若它會被平移，記下平移後的時間）
    final sel = selectedPitch;
    final bool selWillMove = sel != null && sel.start >= start;
    final Duration? selNewStart = selWillMove ? sel.start + delta : null;
    final Duration? selNewEnd = selWillMove ? sel.end + delta : null;

    var pitchData = this.pitchData;

    setState(() {
      // 1) 做平移
      pitchData = pitchData.map((p) {
        if (p.start >= start) {
          return PitchData(pitchIndex: p.pitchIndex, start: p.start + delta, end: p.end + delta);
        }
        return p;
      }).toList();

      // 2) 若選取的那條被平移了，重新在新陣列裡指向它
      if (selWillMove && selNewStart != null && selNewEnd != null) {
        // 以 pitchIndex + start/end 完整匹配，避免誤配
        final idx = pitchData.indexWhere(
          (p) => p.pitchIndex == sel.pitchIndex && p.start == selNewStart && p.end == selNewEnd,
        );
        if (idx != -1) {
          setSelectedPitch(pitchData[idx]);
        } else {
          // 找不到就先清掉，避免指向舊物件
          setSelectedPitch(null);
        }
      }
    });
  }

  List<PitchData> _snapshot(List<PitchData> src) =>
      src.map((p) => PitchData(pitchIndex: p.pitchIndex, start: p.start, end: p.end)).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Combine With Lyrics Demo')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ListView(children: [...buildLyricsAndPitchChildren()])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(border: Border(top: Divider.createBorderSide(context))),
            child: Wrap(
              runSpacing: 12,
              spacing: 12,
              children: [
                // Undo / Redo
                FilledButton.tonalIcon(
                  onPressed: _canUndo ? null : _undo,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _canRedo ? null : _redo,
                  icon: const Icon(Icons.redo),
                  label: const Text('Redo'),
                ),
                FilledButton.tonalIcon(
                  onPressed: debugPrintPitchDataList,
                  icon: const Icon(Icons.code),
                  label: const Text('Print Pitch Data'),
                ),
                if (selectedPitch == null)
                  const Text('點一下上方的 pitch bar 以選取並微調')
                else ...[
                  Text('選取起點: ${selectedPitch!.start.inMilliseconds} ms'),
                  FilledButton(
                    onPressed: () => _shiftPitchesFrom(selectedPitch!.start, const Duration(milliseconds: -10)),
                    child: const Text('-10ms'),
                  ),
                  FilledButton(
                    onPressed: () => _shiftPitchesFrom(selectedPitch!.start, const Duration(milliseconds: -50)),
                    child: const Text('-50ms'),
                  ),
                  FilledButton(
                    onPressed: () => _shiftPitchesFrom(selectedPitch!.start, const Duration(milliseconds: 10)),
                    child: const Text('+10ms'),
                  ),
                  FilledButton(
                    onPressed: () => _shiftPitchesFrom(selectedPitch!.start, const Duration(milliseconds: 50)),
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
