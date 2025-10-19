import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/capture_segment.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/models.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/video_capturer_view_mixin.dart';
import 'package:flutter_desktop_video_capturer/utilities/formatter.dart';
import 'package:flutter_desktop_video_capturer/utils/toast.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/video_capturer_player.dart';
import 'package:flutter_desktop_video_capturer/widgets/video_capturer/video_progress_and_rules_preview_slider.dart';

class CapturerPage extends StatefulWidget {
  const CapturerPage({super.key});

  @override
  State<CapturerPage> createState() => _CapturerPageState();
}

class _CapturerPageState extends State<CapturerPage> with VideoCapturerViewMixin {
  final _scrollController = ScrollController();

  final List<String> _logs = [];

  List<CaptureRule> get _rules => videoCapturer.rules;

  List<Duration> get _stopPoints => videoCapturer.stopPoints;

  int get _defaultIntervalMs => videoCapturer.defaultIntervalMs;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoController = this.videoController;

    return Scaffold(
      appBar: AppBar(title: const Text('Video Frame Extractor'), actions: []),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  ElevatedButton(onPressed: pickVideoForCapturer, child: const Text('選擇影片')),
                  if (videoCapturer.videoPath != null) Text('影片: ${videoCapturer.videoPath}'),
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: tryRunCapturer, child: const Text('開始擷取')),
                  videoController == null
                      ? const Text('請先選擇影片')
                      : VideoCapturerPlayer(videoController: videoController, videoCapturer: videoCapturer),
                  if (videoController != null) ...[
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
                                  onPressed: () {
                                    final pos = videoController.value.position;

                                    final nearest = videoCapturer.nearestRuleFor(pos);
                                    if (nearest == null) {
                                      showToast('找不到最近的開始點（中間有停止點或尚未建立規則）');
                                      return;
                                    }

                                    final ms = (pos - nearest.start).inMilliseconds.abs();
                                    if (ms <= 0) {
                                      showToast('目前時間與最近開始點相同，無法推算間隔');
                                      return;
                                    }

                                    videoCapturer.setDefaultIntervalMs(ms);
                                    setState(() {});
                                    showToast(
                                      '已將預設間隔設為 $ms ms（最近開始點：${Formatter.durationText(nearest.start)} → 目前：${Formatter.durationText(pos)}）',
                                    );

                                    // 若你想同時把「最近那條 rule 的 interval」也一併更新，可解除下列註解：
                                    // final idx = rules.indexWhere((r) => r.start == nearest.start);
                                    // if (idx >= 0) setState(() => rules[idx] = rules[idx].copyWith(interval: Duration(milliseconds: ms)));
                                  },
                                  child: const Text('用最近開始點推算間隔'),
                                ),
                              ],
                            ),

                            VideoProgressAndRulesPreviewSlider(
                              videoController: videoController,
                              videoCapturer: videoCapturer,
                            ),

                            // 規則調整清單（可調整每個 interval / 刪除）
                            const Text('擷取規則', style: TextStyle(fontWeight: FontWeight.bold)),
                            ListView.builder(
                              itemCount: _rules.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, i) {
                                final r = _rules[i];
                                // 即時計算這條規則的 end（顯示用）
                                final seg = videoCapturer
                                    .buildSegments(videoController.value.duration)
                                    .firstWhere((s) => s.rule.start == r.start, orElse: () => CaptureSegment(rule: r));
                                final showEnd = seg.rule.end;
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.play_circle, color: Colors.green),
                                  title: Text(
                                    'Start ${Formatter.durationText(r.start)} → End ${showEnd != null ? Formatter.durationText(showEnd) : '依自動計算'}',
                                  ),
                                  subtitle: Row(
                                    children: [
                                      const Text('間隔(ms): '),
                                      SizedBox(
                                        width: 100,
                                        child: TextFormField(
                                          initialValue: r.interval.inMilliseconds.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(isDense: true),
                                          onChanged: (v) {
                                            final ms = int.tryParse(v.trim());
                                            if (ms != null && ms > 0) {
                                              setState(() {
                                                _rules[i] = r.copyWith(interval: Duration(milliseconds: ms));
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => removeRule(i)),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            const Text('停止點', style: TextStyle(fontWeight: FontWeight.bold)),
                            ListView.builder(
                              itemCount: _stopPoints.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, i) {
                                final s = _stopPoints[i];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.stop_circle, color: Colors.red),
                                  title: Text('Stop @ ${Formatter.durationText(s)}'),
                                  trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => removeStop(i)),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    Row(),
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
                  ],
                  if (videoController != null) ...[
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
                  ],
                ],
              ),
            ),
          ),
          SizedBox(
            height: 300,
            child: Container(
              color: Colors.black,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _logs.length,
                reverse: true,
                itemBuilder: (context, index) {
                  return Text(
                    _logs[index],
                    style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
