import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/env/env.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/video_capturer_view_mixin.dart';
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
  @override
  void initState() {
    super.initState();
    initVideoCapturer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (debugUseDryFlower) {
        pickVideoForCapturer(videoFilePath: debugDryFlowerVideoFilePath);
      }
    });
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
