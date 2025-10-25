import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/env/env.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/tuning_fork/tuning_fork_controller/tuning_fork_controller.dart';
import 'package:flutter_desktop_video_capturer/helpers/combine_with_lyrics/src/combine_with_lyrics_view_mixin.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/detect_pitches_exporter.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/detector_images_pitches_mixin.dart';
import 'package:flutter_desktop_video_capturer/helpers/detector_images_pitches/src/models/detected_pitch_images_adjust_time_info.dart';
import 'package:flutter_desktop_video_capturer/helpers/traceable_history.dart';
import 'package:flutter_desktop_video_capturer/helpers/tuning_fork_player.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/video_capturer_view_mixin.dart';
import 'package:flutter_desktop_video_capturer/models/capture_meta_file.dart';
import 'package:flutter_desktop_video_capturer/widgets/common/area.dart';
import 'package:flutter_desktop_video_capturer/widgets/detector_images_pitches/detector_images_pitches_area.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/capturer_area.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/pick_video_area.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/pick_video_hint.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/video_capturer_player.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/video_progress_and_rules_preview_slider.dart';
import 'package:webview_windows/webview_windows.dart';

enum _PitchesEditorMode {
  byImage,
  byLyrics;

  String get displayName {
    switch (this) {
      case _PitchesEditorMode.byImage:
        return '圖片模式';
      case _PitchesEditorMode.byLyrics:
        return '歌詞模式';
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

// TODO: 強制位移 Detected Image 的起訖時間
/// 主要功能:
///
/// 1. 輸入影片
/// 2. 擷取影片圖片
/// 3. 判斷音高 (圖片識別)
/// 4. 調整音高與時間
/// 5. 輸入字幕
/// 6. 輸出影片
///
/// ## 注意
///
/// - 此 Page 不會用到 [CombineWithLyricsViewMixin] 的修改歌詞功能，僅用來顯示歌詞與音高的結合預覽
/// - debug 狀態下會受 [debugUseDryFlower] 影響，會自動載入指定影片，並且自動略過擷取步驟
class MainFeaturePage extends StatefulWidget {
  const MainFeaturePage({super.key});

  @override
  State<MainFeaturePage> createState() => _MainFeaturePageState();
}

class _MainFeaturePageState extends State<MainFeaturePage>
    with VideoCapturerViewMixin, DetectorImagesPitchesViewMixin, CombineWithLyricsViewMixin {
  late WebviewController _webController;
  late TuningForkController _tuningController;

  late final TuningForkPlayer _tuningForkPlayer;

  _PitchesEditorMode _mode = _PitchesEditorMode.byImage;

  final TraceableHistory<DetectedPitchImagesAdjustTimeInfo> _adjustPitchHistory =
      TraceableHistory<DetectedPitchImagesAdjustTimeInfo>();
  DetectedPitchImagesAdjustTimeInfo _adjustPitchTimeInfo = DetectedPitchImagesAdjustTimeInfo();

  @override
  void initState() {
    super.initState();
    _webController = WebviewController();
    _tuningController = TuningForkController(windowsWebController: _webController);
    _tuningForkPlayer = TuningForkPlayer(_tuningController);

    initVideoCapturer(taskId: debugUseDryFlower ? 'debug_task_don_t_delete' : null);
    initCombineWithLyricsData(useDemoDryFlower: debugUseDryFlower);
    _initWebView();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!debugUseDryFlower) {
        return;
      }

      await pickVideoForCapturer(videoFilePath: debugDryFlowerVideoFilePath);
      debugUpdateRectVideoPx();

      final metaFile = await getCapturerMetaFileIfExists();
      if (metaFile == null) {
        return;
      }

      final captureResultMeta = await CaptureMeta.loadFromFile(metaFile.path);

      final captureOutDir = await getCapturedImagesOutputDirectoryIfExists();
      if (captureOutDir == null) return;

      addRulesAndStopPointsForDebug();

      setState(() {
        setCapturedImageFiles(getCapturedImageFiles(captureOutDir.path));
        setCaptureMeta(captureResultMeta);
      });
    });
  }

  @override
  void dispose() {
    _webController.dispose();
    _tuningController.stop();
    _tuningForkPlayer.stop();
    super.dispose();
  }

  void _initWebView() async {
    final assetsBundle = DefaultAssetBundle.of(context);
    await _webController.initialize();
    final htmlContent = await assetsBundle.loadString('assets/html/oscillator_tuning_fork.html');
    await _webController.loadStringContent(htmlContent);
  }

  void _updateMode(_PitchesEditorMode mode) {
    setState(() {
      _mode = mode;
    });
  }

  Future<void> _tryUpdatePitchDataList({required DetectedPitchImagesAdjustTimeInfo adjustPitchInfo}) async {
    if (detectorImagesPitchesProvider.lastResult == null) {
      print('尚無圖片音高偵測結果，無法匯出');
      return;
    }

    if (captureMeta == null) {
      print('尚無擷取結果資訊，無法匯出');
      return;
    }

    final captureOutDir = await getCapturedImagesOutputDirectoryIfExists();
    if (captureOutDir == null) {
      print('尚無擷取圖片資料夾，無法匯出');
      return;
    }

    final inputFiles = getCapturedImageFiles(captureOutDir.path);
    if (inputFiles.isEmpty) {
      print('擷取圖片資料夾內無圖片，無法匯出');
      return;
    }

    final exporter = DetectPitchesExporter(
      previousStepResult: detectorImagesPitchesProvider.lastResult!,
      metaFile: captureMeta!,
      inputFiles: inputFiles,
      adjustTimeInfo: adjustImageTimeInfo,
    );
    var pitchDataList = exporter.exportToPitchDataList();

    pitchDataList = pitchDataList.map((e) {
      final diff = adjustPitchInfo.getDiffDuration(e.start);
      final adjustedStart = e.start + diff;
      final adjustedEnd = e.end + diff;
      return e.copyWith(start: adjustedStart, end: adjustedEnd);
    }).toList();
    setPitchDataList(pitchDataList);
  }

  Future<void> _shiftPitchesFrom(Duration start, Duration delta) async {
    // 先記住目前選取的 pitch（若它會被平移，記下平移後的時間）
    final sel = selectedPitch;
    final bool selWillMove = sel != null && sel.start >= start;
    final Duration? selNewStart = selWillMove ? sel.start + delta : null;
    final Duration? selNewEnd = selWillMove ? sel.end + delta : null;

    if (sel == null) {
      return;
    }

    final originalStartTime = _adjustPitchTimeInfo.getOriginalDuration(sel.start);
    final newAdjustInfo = _adjustPitchTimeInfo.cloneAndAddAdjustDetail(originalStartTime, delta);
    _adjustPitchHistory.add(newAdjustInfo);
    _adjustPitchTimeInfo = newAdjustInfo;
    setState(() {});

    await _tryUpdatePitchDataList(adjustPitchInfo: _adjustPitchTimeInfo);

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
  }

  Widget _buildBody(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isGreaterTabletWidth = screenSize.width >= 1200;
    final videoController = this.videoController;

    if (videoController == null) {
      return PickVideoHint(pickVideo: pickVideoForCapturer);
    }

    final previewContentItems = switch (_mode) {
      _PitchesEditorMode.byImage => [
        if (capturedImageFiles.isEmpty)
          const Text('尚無擷取圖片，請先執行擷取')
        else
          ...buildDetectedPitchesImageViews(
            onPlay: (frameTimeInfo) {
              print(frameTimeInfo.startTime);
              videoController.seekTo(frameTimeInfo.startTime);
            },
          ),
      ],
      _PitchesEditorMode.byLyrics => [
        SizedBox(height: 8),
        ...buildLyricsAndPitchChildren(
          onPlayLine: (line) async {
            if (_tuningForkPlayer.isPlaying) {
              await _tuningForkPlayer.stop();
            } else {
              await _tuningForkPlayer.playSequence(
                pitchData,
                startAt: line.startTime,
                // endAt: line.endTime
              );
            }
          },
        ),
      ],
    };

    Widget leftOrMainBodyContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              PickVideoArea(pickVideo: pickVideoForCapturer, currentVideoPath: videoCapturer.videoPath),
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

              DetectorImagesPitchesArea(
                onClearGridLines: gridLinesY.isEmpty || isDetectingImagesPitches
                    ? null
                    : () async {
                        if (isDetectingImagesPitches) return;
                        await clearGridLines();
                        final inputDir0 = await getCapturedImagesOutputDirectoryIfExists();
                        if (inputDir0 == null) return;
                        tryRunDetectImagesPitches(inputDir: inputDir0.path);
                      },
                onLoadGridLines: isDetectingImagesPitches
                    ? null
                    : () async {
                        await debugSetGridLines();
                        final inputDir = await getCapturedImagesOutputDirectoryIfExists();
                        if (inputDir == null) return;
                        await tryRunDetectImagesPitches(inputDir: inputDir.path);
                      },
              ),
              ContentArea(
                title: '預覽設定',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('選擇模式'),
                    SizedBox(height: 8),
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
                    SizedBox(height: 8),
                    ...switch (_mode) {
                      _PitchesEditorMode.byImage => [
                        Text('預覽設定'),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
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
                            SizedBox(width: 8),
                            // TODO: 目前需手動，之後要自動處理
                            FilledButton.icon(
                              onPressed: () => _tryUpdatePitchDataList(adjustPitchInfo: _adjustPitchTimeInfo),
                              icon: const Icon(Icons.bug_report_outlined),
                              label: const Text('暫時: Image Result to Pitch Data'),
                            ),
                          ],
                        ),
                      ],
                      _PitchesEditorMode.byLyrics => [
                        Wrap(
                          runSpacing: 12,
                          spacing: 12,
                          children: [
                            if (selectedPitch == null)
                              const Text('點一下上方的 pitch bar 以選取並微調')
                            else ...[
                              Text('選取起點: ${selectedPitch!.start.inMilliseconds} ms'),
                              FilledButton(
                                onPressed: () =>
                                    _shiftPitchesFrom(selectedPitch!.start, const Duration(milliseconds: -10)),
                                child: const Text('-10ms'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    _shiftPitchesFrom(selectedPitch!.start, const Duration(milliseconds: -50)),
                                child: const Text('-50ms'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    _shiftPitchesFrom(selectedPitch!.start, const Duration(milliseconds: 10)),
                                child: const Text('+10ms'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    _shiftPitchesFrom(selectedPitch!.start, const Duration(milliseconds: 50)),
                                child: const Text('+50ms'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    },
                    SizedBox(height: 8),
                    Text('調整圖片時間 (根據歌詞模式所選擇的截圖)'),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton(
                          onPressed: () {
                            final newAdjustPitchInfo = DetectedPitchImagesAdjustTimeInfo();
                            _adjustPitchHistory.add(newAdjustPitchInfo);
                            _adjustPitchTimeInfo = newAdjustPitchInfo;
                            setState(() {});
                          },
                          child: Text('清除針對歌詞的調整'),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('調整圖片時間 (根據圖片模式所選擇的截圖)'),
                    SizedBox(height: 8),
                    if (selectedImageFile == null)
                      const Text('點一下上方的圖片以選取並微調', style: TextStyle(color: Colors.grey))
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ...[-1, 1]
                              .map(
                                (multiplier) => [1000, 500, 100, 50, 10].map(
                                  (ms) => FilledButton(
                                    onPressed: () {
                                      shiftImagePitchesFrom(
                                        selectedImageFile!,
                                        Duration(milliseconds: ms * multiplier),
                                      );
                                      _tryUpdatePitchDataList(adjustPitchInfo: _adjustPitchTimeInfo);
                                    },
                                    child: Text('${multiplier * ms}ms'),
                                  ),
                                ),
                              )
                              .expand((e) => e),
                          FilledButton(onPressed: () => clearAdjustTimeInfo(), child: const Text('清除調整')),
                        ],
                      ),
                  ],
                ),
              ),
              Container(margin: const EdgeInsets.only(top: 16), height: 100, child: Webview(_webController)),
              ElevatedButton(
                onPressed: () {
                  if (_tuningForkPlayer.isPlaying) {
                    _tuningForkPlayer.stop();
                  } else {
                    _tuningForkPlayer.playSequence(pitchData);
                  }
                },
                child: Text('Play Test'),
              ),
              if (!isGreaterTabletWidth)
                ContentArea(
                  title: '預覽內容',
                  canExpand: false,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: previewContentItems),
                ),
            ],
          ),
        ),
      ],
    );

    if (!isGreaterTabletWidth) {
      return leftOrMainBodyContent;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: leftOrMainBodyContent),
        SizedBox(width: 16),
        Expanded(
          child: ContentArea(
            title: '預覽內容',
            canExpand: false,
            shrinkWrap: false,
            child: ListView(padding: const EdgeInsets.fromLTRB(0, 0, 16, 40), children: previewContentItems),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('主要功能'), actions: []),
      body: _buildBody(context),
    );
  }
}
