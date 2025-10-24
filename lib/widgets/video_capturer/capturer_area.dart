import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/capture_segment.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/video_capturer.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/video_capturer_view_mixin.dart';
import 'package:flutter_desktop_video_capturer/utilities/formatter.dart';
import 'package:flutter_desktop_video_capturer/widgets/common/area.dart';
import 'package:video_player/video_player.dart';

class CapturerSettingsArea extends StatelessWidget {
  const CapturerSettingsArea(this.capturerViewMixin, {super.key});

  final VideoCapturerViewMixin capturerViewMixin;

  VideoCapturer get videoCapturer => capturerViewMixin.videoCapturer;

  VideoPlayerController get videoController => capturerViewMixin.videoController!;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    final isCompact = screenSize.width < 600;

    return ContentArea(
      title: '擷取設定',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 規則調整清單（可調整每個 interval / 刪除）
          const Text('擷取規則'),
          const SizedBox(height: 8),
          ListView.builder(
            itemCount: videoCapturer.rules.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, i) {
              final r = videoCapturer.rules[i];
              // 即時計算這條規則的 end（顯示用）
              final seg = videoCapturer
                  .buildSegments(videoController.value.duration)
                  .firstWhere((s) => s.rule.start == r.start, orElse: () => CaptureSegment(rule: r));
              final showEnd = seg.rule.end;

              final textField = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('間隔(ms): '),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      initialValue: r.interval.inMilliseconds.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (v) => capturerViewMixin.onRuleIntervalChange(v, i, r),
                    ),
                  ),
                ],
              );

              return ListTile(
                dense: true,
                leading: const Icon(Icons.play_circle, color: Colors.green),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: BoxConstraints(minWidth: 200),
                      child: Text(
                        '${Formatter.durationText(r.start)} → ${showEnd != null ? Formatter.durationText(showEnd) : '依自動計算'}',
                      ),
                    ),
                    if (!isCompact) ...[const SizedBox(width: 16), textField],
                  ],
                ),
                subtitle: isCompact ? textField : null,
                trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => capturerViewMixin.removeRule(i)),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text('停止點'),
          const SizedBox(height: 8),
          ListView.builder(
            itemCount: videoCapturer.stopPoints.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, i) {
              final s = videoCapturer.stopPoints[i];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.stop_circle, color: Colors.red),
                title: Text('Stop @ ${Formatter.durationText(s)}'),
                trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => capturerViewMixin.removeStop(i)),
              );
            },
          ),
        ],
      ),
    );
  }
}
