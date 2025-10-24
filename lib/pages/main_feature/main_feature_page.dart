import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/combine_with_lyrics/src/combine_with_lyrics_view_mixin.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/detector_images_pitches_mixin.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/video_capturer_view_mixin.dart';
import 'package:flutter_desktop_video_capturer/utilities/formatter.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/capturer_area.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/pick_video_area.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/pick_video_hint.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/video_capturer_player.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/video_progress_and_rules_preview_slider.dart';

enum _PitchesEditorMode {
  byImage,
  byLyrics;

  String get displayName {
    switch (this) {
      case _PitchesEditorMode.byImage:
        return '圖片辨識模式';
      case _PitchesEditorMode.byLyrics:
        return '歌詞編輯模式';
    }
  }

  IconData get iconData {
    switch (this) {
      case _PitchesEditorMode.byImage:
        return Icons.image;
      case _PitchesEditorMode.byLyrics:
        return Icons.subtitles;
    }
  }
}

/// 主要功能:
///
/// 1. 輸入影片
/// 2. 擷取影片圖片
/// 3. 判斷音高 (圖片識別)
/// 4. 調整音高與時間
/// 5. 輸入字幕
/// 6. 輸出影片
class MainFeaturePage extends StatefulWidget {
  const MainFeaturePage({super.key});

  @override
  State<MainFeaturePage> createState() => _MainFeaturePageState();
}

class _MainFeaturePageState extends State<MainFeaturePage>
    with VideoCapturerViewMixin, DetectorImagesPitchesViewMixin, CombineWithLyricsViewMixin {
  _PitchesEditorMode _mode = _PitchesEditorMode.byImage;

  @override
  void initState() {
    super.initState();
    initVideoCapturer();
    initCombineWithLyricsData();
  }

  void _updateMode(_PitchesEditorMode mode) {
    setState(() {
      _mode = mode;
    });
  }

  Widget _buildBody(BuildContext context) {
    final videoController = this.videoController;

    if (videoController == null) {
      return PickVideoHint(pickVideo: pickVideoForCapturer);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                PickVideoArea(
                  pickVideo: pickVideoForCapturer,
                  currentVideoPath: videoCapturer.videoPath,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final captureResultMeta = await tryRunCapturer();

                    setState(() {
                      setCaptureMeta(captureResultMeta);
                    });

                    final metaFile = await getCapturerMetaFileIfExists();
                    if (metaFile == null) {
                      return;
                    }

                    final captureOutDir = await getCapturedImagesOutputDirectoryIfExists();
                    if (captureOutDir == null) return;

                    setState(() {
                      setCapturedImageFiles(getCapturedImageFiles(captureOutDir.path));
                      setCaptureMeta(captureResultMeta);
                    });
                  },
                  child: const Text('開始擷取'),
                ),
                VideoCapturerPlayer(videoController: videoController, videoCapturer: videoCapturer),
                ValueListenableBuilder(
                  valueListenable: videoController,
                  builder: (context, value, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  if (videoController.value.isPlaying) {
                                    videoController.pause();
                                  } else {
                                    videoController.play();
                                  }
                                },
                                icon: Icon(videoController.value.isPlaying ? Icons.pause : Icons.play_arrow),
                              ),
                              Text(
                                '${Formatter.durationText(videoController.value.position)} / ${Formatter.durationText(videoController.value.duration)}',
                              ),
                              // 快速設定預設 interval
                              const Text('新規則間隔(ms): '),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  controller: TextEditingController(text: videoCapturer.defaultIntervalMs.toString()),
                                  onSubmitted: (v) {
                                    final ms = int.tryParse(v.trim());
                                    if (ms == null || ms <= 0) {
                                      return;
                                    }
                                    videoCapturer.setDefaultIntervalMs(ms);
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: addRuleAtCurrent,
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('在目前時間加入開始點'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: addStopAtCurrent,
                                icon: const Icon(Icons.stop_circle_outlined),
                                label: const Text('在目前時間加入停止點'),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: '上一個擷取點',
                              icon: const Icon(Icons.skip_previous),
                              onPressed: goToPrevStepInCapturer,
                            ),
                            IconButton(
                              tooltip: '下一個擷取點',
                              icon: const Icon(Icons.skip_next),
                              onPressed: goToNextStepInCapturer,
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => updateIntervalFromLastRule(videoController),
                              child: const Text('用最近開始點推算間隔'),
                            ),
                          ],
                        ),

                        VideoProgressAndRulesPreviewSlider(
                          videoController: videoController,
                          videoCapturer: videoCapturer,
                        ),

                        CapturerSettingsArea(this),
                      ],
                    );
                  },
                ),
                Row(
                  children: [
                    Text('Volume'),
                    // slider
                    Expanded(
                      child: Slider(
                        value: videoController.value.volume,
                        onChanged: (value) {
                          videoController.setVolume(value);
                          setState(() {});
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        videoController.setVolume(videoController.value.volume > 0 ? 0 : 1);
                        setState(() {});
                      },
                      icon: Icon(
                        videoController.value.volume == 0 ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                      ),
                    ),
                  ],
                ),

                Text('個人常用設定'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        videoCapturer.setRectVideoPx(Rect.fromLTWH(0, 155, 1920, 260));
                        // dragStartVideoPx;
                        setState(() {});
                      },
                      child: Text('設定擷取範圍'),
                    ),
                    // 微調時間
                    ...[-1, 1]
                        .map(
                          (sign) => [1000, 500, 300, 100, 50, 10, 1].map(
                            (ms) => ElevatedButton(
                              onPressed: () {
                                var start = videoController.value.position;
                                start += Duration(milliseconds: sign * ms);
                                videoController.seekTo(start);
                                setState(() {});
                              },
                              child: Text('${sign < 0 ? '-' : '+'}$ms ms'),
                            ),
                          ),
                        )
                        .expand((e) => e),
                  ],
                ),
                Text('Debug 專用 (For 乾燥花)'),
                Wrap(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        videoCapturer.addRulesAndStopPointsForDebug();
                        setState(() {});
                      },
                      child: Text('設定擷取規則和停止點'),
                    ),
                  ],
                ),
                Divider(),
                Text('辨識圖片相關'),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: gridLinesY.isEmpty || isDetectingImagesPitches
                          ? null
                          : () async {
                              if (isDetectingImagesPitches) return;
                              await clearGridLines();
                              final inputDir0 = await getCapturedImagesOutputDirectoryIfExists();
                              if (inputDir0 == null) return;
                              tryRunDetectImagesPitches(inputDir: inputDir0.path);
                            },
                      icon: const Icon(Icons.clear),
                      label: const Text('清空'),
                    ),
                    FilledButton.icon(
                      onPressed: isDetectingImagesPitches
                          ? null
                          : () async {
                              await debugSetGridLines();
                              final inputDir = await getCapturedImagesOutputDirectoryIfExists();
                              if (inputDir == null) return;
                              await tryRunDetectImagesPitches(inputDir: inputDir.path);
                            },
                      icon: const Icon(Icons.download),
                      label: Text('載入'),
                    ),
                  ],
                ),
                Text('選擇預覽或編輯模式'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _PitchesEditorMode.values.map((mode) {
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [Icon(mode.iconData), const SizedBox(width: 8), Text(mode.displayName)],
                      ),
                      selected: _mode == mode,
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) {
                          _updateMode(mode);
                        }
                      },
                    );
                  }).toList(),
                ),
                ...switch (_mode) {
                  _PitchesEditorMode.byImage => [
                    Text('預覽擷取圖片'),
                    Wrap(
                      children: [
                        FilledButton.icon(
                          onPressed: togglePreviewImagesDetectResult,
                          icon: Icon(isPreviewImagesDetectResult ? Icons.visibility : Icons.visibility_off),
                          label: Text(isPreviewImagesDetectResult ? '關閉音階預覽' : '開啟音階預覽'),
                        ),
                        SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            detectorImagesPitchesProvider.tmp();
                          },
                          icon: const Icon(Icons.bug_report_outlined),
                          label: const Text('暫時用'),
                        ),
                      ],
                    ),
                    if (capturedImageFiles.isEmpty)
                      const Text('尚無擷取圖片，請先執行擷取')
                    else
                      ...buildDetectedPitchesImageViews(),
                  ],
                  _PitchesEditorMode.byLyrics => [
                    SizedBox(height: 8),
                    Wrap(
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
                        ...buildLyricsAndPitchChildren(),
                      ],
                    ),
                  ],
                },
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Frame Extractor'), actions: []),
      body: _buildBody(context),
    );
  }
}
