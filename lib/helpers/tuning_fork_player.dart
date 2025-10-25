import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/models/note_name.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/models/pitch_name.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/tuning_fork/enums.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/tuning_fork/tuning_fork_controller/tuning_fork_controller.dart';
import 'package:flutter_desktop_video_capturer/helpers/combine_with_lyrics/src/models/pitch_data.dart';

class TuningForkPlayer {
  TuningForkPlayer(this.controller, {
    this.defaultVolume = 0.1,
    this.defaultWaveform = Waveform.sine,

  });

  final TuningForkController controller;
  final double defaultVolume;
  final Waveform defaultWaveform;

  final _stopToken = _StopToken();

  bool get isPlaying => !_stopToken.stopped;

  /// 播放一串音符。`notes` 的 start/end 皆以同一時間軸（相對 0）計。
  /// 若有重疊，後開始者會覆蓋前者（單音器）。
  Future<void> playSequence(List<PitchData> notes, {
    Duration startAt = Duration.zero,
    Duration? endAt,
  }) async {
    if (notes.isEmpty) return;

    // 事件：note-on / note-off
    final events = <_Event>[];

    for (final n in notes) {
      events.add(_Event(time: n.start, type: _EventType.on, pitchIndex: n.pitchIndex));
      events.add(_Event(time: n.end, type: _EventType.off, pitchIndex: n.pitchIndex));
    }
    // 依時間排序；同時刻先 off 再 on，避免毛刺
    events.sort((a, b) {
      final t = a.time.compareTo(b.time);
      if (t != 0) return t;
      if (a.type == b.type) return 0;
      return a.type == _EventType.off ? -1 : 1;
    });

    // 找出 startAt 當下應該在鳴的音（單音邏輯：取最後一個 start<=startAt<end）
    _Event? lastOnBefore;
    _Event? firstOffAfter;

    for (final n in notes) {
      if (n.start <= startAt && startAt < n.end) {
        // 取「開始時間最大」的那個
        if (lastOnBefore == null || n.start > lastOnBefore.time) {
          lastOnBefore = _Event(time: n.start, type: _EventType.on, pitchIndex: n.pitchIndex);
          firstOffAfter = _Event(time: n.end, type: _EventType.off, pitchIndex: n.pitchIndex);
        }
      }
    }

    // 把 startAt 之前的事件捨棄，之後的事件時間改為「相對 startAt」
    final tail = <_Event>[];
    for (final e in events) {
      if (e.time >= startAt && (endAt == null || e.time < endAt)) {
        tail.add(_Event(
          time: e.time - startAt,
          type: e.type,
          pitchIndex: e.pitchIndex,
        ));
      }
    }

    // 若起點當下本來就該在鳴音，插入一個立即的 on 事件於 t=0，並確保有對應的 off 在隊列內
    if (lastOnBefore != null) {
      tail.insert(
        0,
        _Event(time: Duration.zero, type: _EventType.on, pitchIndex: lastOnBefore.pitchIndex),
      );
      // 如果對應 off 在 startAt 之後，時間也要平移
      if (firstOffAfter != null) {
        final offTime = firstOffAfter.time - startAt;
        // 若 tail 內已經有相同音的 off（通常會有），就不用特別加
        final hasOff = tail.any((e) =>
        e.type == _EventType.off &&
            e.time == offTime &&
            e.pitchIndex == firstOffAfter!.pitchIndex);
        if (!hasOff) {
          tail.add(_Event(time: offTime, type: _EventType.off, pitchIndex: firstOffAfter.pitchIndex));
        }
        tail.sort((a, b) {
          final t = a.time.compareTo(b.time);
          if (t != 0) return t;
          if (a.type == b.type) return 0;
          return a.type == _EventType.off ? -1 : 1;
        });
      }
    }

    if (tail.isEmpty) {
      // startAt 已超過結尾；什麼都不播
      return;
    }

    // 初始化基本參數
    await controller.setVolume(defaultVolume);
    await controller.setWaveform(defaultWaveform);
    await controller.stop();

    _stopToken.reset();
    final sw = Stopwatch()..start();

    // 目前是否有音在播
    bool noteOn = false;

    for (final e in tail) {
      // 若被外部 stop
      if (_stopToken.stopped) break;

      // 等待到事件時間（以單調時鐘追趕，避免累積誤差）
      final waitUs = e.time.inMicroseconds - sw.elapsedMicroseconds;
      if (waitUs > 0) {
        // 先用粗延遲到接近，再用短延遲逼近，減少 Event Loop 抖動
        final ms = waitUs ~/ 1000;
        final remainderUs = waitUs % 1000;
        if (ms > 1) await Future.delayed(Duration(milliseconds: ms - 1));
        if (remainderUs > 0) {
          final targetUs = e.time.inMicroseconds;
          while (sw.elapsedMicroseconds < targetUs) {
            await Future.delayed(const Duration(microseconds: 100));
          }
        }
      }

      // 執行事件
      if (e.type == _EventType.off) {
        if (noteOn) {
          await controller.stop();
          noteOn = false;
        }
      } else {
        final basePitchAtIndex0 = PitchName.fromNoteOctave(NoteName.gSharp, 3);
        final hz = basePitchAtIndex0.getNext(e.pitchIndex).value;
        // 若已在播，直接換頻率；否則先設定再 play
        if (noteOn) {
          await controller.setFrequency(hz);
        } else {
          await controller.play(frequency: hz, volume: defaultVolume, waveform: defaultWaveform);
          noteOn = true;
        }
      }
    }

    // 末尾若還在播，收掉
    if (noteOn && !_stopToken.stopped) {
      await controller.stop();
    }
  }

  Future<void> stop() async {
    _stopToken.stop();
    await controller.stop();
  }
}

enum _EventType { on, off }

class _Event {
  _Event({required this.time, required this.type, required this.pitchIndex});

  final Duration time;
  final _EventType type;
  final int pitchIndex;
}

class _StopToken {
  bool stopped = false;

  void stop() => stopped = true;

  void reset() => stopped = false;
}
