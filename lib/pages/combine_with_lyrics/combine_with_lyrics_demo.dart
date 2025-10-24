import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/combine_with_lyrics/src/combine_with_lyrics_view_mixin.dart';

const minGap = Duration(milliseconds: 120); // 視情況調整閾值

class CombineWithLyricsDemoPage extends StatefulWidget {
  const CombineWithLyricsDemoPage({super.key});

  @override
  State<CombineWithLyricsDemoPage> createState() => _CombineWithLyricsDemoPageState();
}

class _CombineWithLyricsDemoPageState extends State<CombineWithLyricsDemoPage> with CombineWithLyricsViewMixin {
  @override
  void initState() {
    super.initState();
    initCombineWithLyricsData();
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
                  onPressed: undoStack.isEmpty ? null : undo,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
                FilledButton.tonalIcon(
                  onPressed: redoStack.isEmpty ? null : redo,
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
                    onPressed: () => shiftPitchesFrom(selectedPitch!.start, const Duration(milliseconds: -10)),
                    child: const Text('-10ms'),
                  ),
                  FilledButton(
                    onPressed: () => shiftPitchesFrom(selectedPitch!.start, const Duration(milliseconds: -50)),
                    child: const Text('-50ms'),
                  ),
                  FilledButton(
                    onPressed: () => shiftPitchesFrom(selectedPitch!.start, const Duration(milliseconds: 10)),
                    child: const Text('+10ms'),
                  ),
                  FilledButton(
                    onPressed: () => shiftPitchesFrom(selectedPitch!.start, const Duration(milliseconds: 50)),
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
