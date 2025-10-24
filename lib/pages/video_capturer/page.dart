import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/models.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/video_capturer_view_mixin.dart';
import 'package:flutter_desktop_video_capturer/utilities/formatter.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/capturer_area.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/pick_video_area.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/pick_video_hint.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/video_capturer_player.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/video_progress_and_rules_preview_slider.dart';

class CapturerPage extends StatefulWidget {
  const CapturerPage({super.key});

  @override
  State<CapturerPage> createState() => _CapturerPageState();
}

class _CapturerPageState extends State<CapturerPage> with VideoCapturerViewMixin {
  List<CaptureRule> get _rules => videoCapturer.rules;

  List<Duration> get _stopPoints => videoCapturer.stopPoints;

  int get _defaultIntervalMs => videoCapturer.defaultIntervalMs;

  @override
  void initState() {
    super.initState();
    initVideoCapturer();
  }

  Widget _buildBody(BuildContext context) {
    final videoController = this.videoController;

    if (videoController == null) {
      if (videoController == null) {
        return PickVideoHint(pickVideo: pickVideoForCapturer);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                PickVideoArea(pickVideo: pickVideoForCapturer, currentVideoPath: videoCapturer.videoPath),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: tryRunCapturer, child: const Text('開始擷取')),
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
                              // 快速設定預設 interval
                              const Text('新規則間隔(ms): '),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  controller: TextEditingController(text: _defaultIntervalMs.toString()),
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
                Text('預覽擷取圖片'),
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
