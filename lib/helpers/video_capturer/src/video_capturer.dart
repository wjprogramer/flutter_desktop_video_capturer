import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/helpers/video_capturer/src/capture_segment.dart';
import 'package:flutter_desktop_video_capturer/models/base/src/value_object.dart';
import 'package:flutter_desktop_video_capturer/models/capture_meta_file.dart';
import 'package:path/path.dart' as p;

import 'models.dart';

class VideoCapturer {
  VideoCapturer();

  String? _videoPath;

  String? get videoPath => _videoPath;

  //Rect.fromLTWH(0, 0, 2160, 1440),
  Rect? _rectVideoPx;

  /// 以「影片像素」為座標系來存
  Rect? get rectVideoPx => _rectVideoPx;

  // 預設加入規則的 interval（可在 UI 調整每條）
  int _defaultIntervalMs = 1200;

  int get defaultIntervalMs => _defaultIntervalMs;

  /// 擷取規則
  final List<CaptureRule> _rules = [];

  List<CaptureRule> get rules => List.unmodifiable(_rules);

  /// 單純的停止點時間列表（毫秒精度）
  final List<Duration> _stopPoints = [];

  List<Duration> get stopPoints => List.unmodifiable(_stopPoints);

  Size? _videoSizePx; // 例如 1920x1080

  Size? get videoSizePx => _videoSizePx;

  void setDefaultIntervalMs(int ms) {
    _defaultIntervalMs = ms;
  }

  void setVideoPath(String path, Size videoSize) {
    _videoPath = path;
    _videoSizePx = videoSize;
  }

  void setRectVideoPx(Rect? rect) {
    _rectVideoPx = rect;
  }

  void addRuleAt(Duration pos) {
    // 避免重複時間的規則（允許但會導致 0 長度段）
    _rules.add(
      CaptureRule(
        start: pos,
        end: null, // 執行前會自動推導
        interval: Duration(milliseconds: _defaultIntervalMs),
        rect: _rectVideoPx!,
      ),
    );
    _rules.sort((a, b) => a.start.compareTo(b.start));
  }

  void removeRuleAt(int index) {
    _rules.removeAt(index);
  }

  void addStopAt(Duration now) {
    if (!_stopPoints.any((d) => (d - now).inMilliseconds.abs() <= 1)) {
      _stopPoints.add(now);
      _stopPoints.sort((a, b) => a.compareTo(b));
    }
  }

  void removeStopAt(int index) {
    _stopPoints.removeAt(index);
  }

  /// 由 rules + stopPoints 推導每段擷取區間
  List<CaptureSegment> buildSegments(Duration videoDuration) {
    final sortedRules = [..._rules].map((e) => e.copyWith(rect: _rectVideoPx)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final stops = [..._stopPoints]..sort((a, b) => a.compareTo(b));

    final segList = <CaptureSegment>[];
    for (int i = 0; i < sortedRules.length; i++) {
      final r = sortedRules[i];
      // 下一個規則起始
      Duration? nextRuleStart;
      if (i + 1 < sortedRules.length) nextRuleStart = sortedRules[i + 1].start;

      // 下一個停止點（在 r.start 之後）
      Duration? nextStop;
      for (final s in stops) {
        if (s > r.start) {
          nextStop = s;
          break;
        }
      }

      // 候選 end = [nextRuleStart, nextStop, videoEnd]
      Duration end = videoDuration;
      if (nextRuleStart != null && nextRuleStart < end) end = nextRuleStart;
      if (nextStop != null && nextStop < end) end = nextStop;

      if (end > r.start && r.interval.inMilliseconds > 0 && r.rect.width > 0 && r.rect.height > 0) {
        segList.add(CaptureSegment(rule: r.copyWith(end: ValueObject(end))));
      }
    }
    return segList;
  }

  /// 找到「<= 當前位置」的擷取點 index（不存在回傳 -1）
  int indexOfPrevCapture(List<Duration> times, Duration pos) {
    int lo = 0, hi = times.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (times[mid] <= pos) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  /// 從 segments 算出所有「預計擷取時間點」(已含每個 rule 的 start)
  List<Duration> plannedCaptureTimesFromSegments(List<CaptureSegment> segList) {
    final out = <Duration>[];
    for (final seg in segList) {
      final r = seg.rule;
      final startMs = r.start.inMilliseconds;
      final endMs = (r.end ?? r.start).inMilliseconds;
      final step = r.interval.inMilliseconds;
      if (step <= 0) continue;
      for (int t = startMs; t <= endMs; t += step) {
        out.add(Duration(milliseconds: t));
      }
    }
    out.sort((a, b) => a.compareTo(b));
    // 去重（避免鄰接段落首尾重疊）
    final dedup = <Duration>[];
    for (final d in out) {
      if (dedup.isEmpty || dedup.last != d) dedup.add(d);
    }
    return dedup;
  }

  /// 把「影片像素座標」轉回螢幕（為了畫框用）
  Rect videoRectToScreen(Rect rVideo, Size paintSize) {
    final vw = _videoSizePx!.width;
    final vh = _videoSizePx!.height;
    final scale = math.min(paintSize.width / vw, paintSize.height / vh);
    final displayW = vw * scale;
    final displayH = vh * scale;
    final dx = (paintSize.width - displayW) / 2.0;
    final dy = (paintSize.height - displayH) / 2.0;

    return Rect.fromLTWH(
      dx + rVideo.left * scale,
      dy + rVideo.top * scale,
      rVideo.width * scale,
      rVideo.height * scale,
    );
  }

  /// 把螢幕上的 localPosition（Stack child 的座標，單位邏輯 px）映射到「影片像素座標」
  Offset? screenToVideo(Offset p, Size paintSize) {
    if (_videoSizePx == null) return null;

    // 以 BoxFit.contain 計算影片顯示矩形（在 paintSize 內）
    final vw = _videoSizePx!.width;
    final vh = _videoSizePx!.height;
    final scale = math.min(paintSize.width / vw, paintSize.height / vh);
    final displayW = vw * scale;
    final displayH = vh * scale;
    final dx = (paintSize.width - displayW) / 2.0;
    final dy = (paintSize.height - displayH) / 2.0;
    final displayRect = Rect.fromLTWH(dx, dy, displayW, displayH);

    // 若座標在影片外的 letterbox 區域，忽略
    if (!displayRect.contains(p)) return null;

    // 反投影：先扣掉 offset，再除以 scale
    final vx = (p.dx - displayRect.left) / scale;
    final vy = (p.dy - displayRect.top) / scale;

    // 夾在影片邊界內（避免負數/超界）
    final clampedX = vx.clamp(0.0, vw);
    final clampedY = vy.clamp(0.0, vh);
    return Offset(clampedX, clampedY);
  }

  /// 嘗試開始執行擷取
  void tryExecute() {}

  /// ## 注意路徑
  ///
  /// 如果有改到路徑相關要特別注意。
  ///
  /// `meta.json` 的路徑有變動時，注意要修改 [getMetaFilePath]
  /// 目前的邏輯是 [outputDir]/captures/meta.json
  ///
  /// `captures` 資料夾的路徑有變動時，注意要修改 [getCaptureOutputDir]
  Future<CaptureMeta> runCapture({
    required String inputPath,
    required String outputDir,
    required Duration start, // 保留參數相容，但實際改用 rules
    required Duration interval, // 保留參數相容
    required Duration videoDuration,
  }) async {
    if (_videoPath == null || _rules.isEmpty || _rectVideoPx == null) {
      throw Exception('Video path, rules, or rect is not set.');
    }
    final newRules = _rules.map((e) => e.copyWith(rect: _rectVideoPx!)).toList();
    var imageIndex = 0;

    final segList = buildSegments(videoDuration);
    if (segList.isEmpty) {
      throw Exception('沒有有效的擷取區段，請至少加入一個規則（開始點）');
    }

    // 建立輸出資料夾
    final dir = Directory(outputDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final projectDir = Directory(p.join(dir.path, 'captures'));
    if (!projectDir.existsSync()) {
      projectDir.createSync(recursive: true);
    }

    final meta = CaptureMeta.from(
      rectVideoPx: _rectVideoPx!,
      videoPath: _videoPath,
      rules: newRules,
      stopPoints: _stopPoints,
    );

    print('共 ${segList.length} 段要擷取');

    for (int i = 0; i < segList.length; i++) {
      final seg = segList[i];
      final r = seg.rule; // 已帶有 end
      final segDir = Directory(p.join(projectDir.path)); // , 'seg_$i'
      if (!segDir.existsSync()) segDir.createSync(recursive: true);

      final x = r.rect.left.round();
      final y = r.rect.top.round();
      final w = r.rect.width.round();
      final h = r.rect.height.round();

      // Future<void> forceCaptureSegStart() async {
      //   // 先強制擷取「段落起點」的一張
      //   final startStillPath = p.join(segDir.path, 'frame_0000.png');
      //   final argsStart = [
      //     '-hide_banner',
      //     '-loglevel',
      //     'info',
      //     '-ss',
      //     (r.start.inMilliseconds / 1000).toStringAsFixed(3),
      //     '-i',
      //     inputPath,
      //     '-vf',
      //     'crop=$w:$h:$x:$y',
      //     '-frames:v',
      //     '1',
      //     startStillPath,
      //   ];
      //   print('執行(起點單張): ffmpeg ${argsStart.join(' ')}');
      //   try {
      //     final pStart = await Process.start('ffmpeg', argsStart);
      //     pStart.stdout.transform(SystemEncoding().decoder).listen((d) => print('stdout: $d'));
      //     pStart.stderr.transform(SystemEncoding().decoder).listen((d) => print('stderr: $d'));
      //     final codeStart = await pStart.exitCode;
      //     print('起點單張完成 seg_$i，exit=$codeStart');
      //   } catch (e) {
      //     print('起點單張失敗 seg_$i: $e');
      //   }
      // }
      //
      // await forceCaptureSegStart();

      // 計算 fps (interval 毫秒 -> 1 / 秒數)
      final fps = 1 / (r.interval.inMilliseconds / 1000.0);
      final durationSec = ((r.end ?? videoDuration) - r.start).inMilliseconds / 1000.0;

      final args = [
        '-hide_banner',
        '-loglevel',
        'info',
        '-ss',
        (r.start.inMilliseconds / 1000).toStringAsFixed(3),
        '-i',
        inputPath,
        '-t',
        durationSec.toStringAsFixed(3),
        '-vf',
        'crop=$w:$h:$x:$y,fps=$fps',
        // %04d => 避免後面排序有問題
        // ffmpeg 預設從 1 開始編號，所以前面強制擷取的起點單張是 frame_0000.png
        p.join(segDir.path, 'frame_%04d.png'),
      ];

      print('執行: ffmpeg ${args.join(' ')}');
      try {
        final process = await Process.start('ffmpeg', args);
        process.stdout.transform(SystemEncoding().decoder).listen((data) => print('stdout: $data'));
        process.stderr.transform(SystemEncoding().decoder).listen((data) => print('stderr: $data'));
        final code = await process.exitCode;

        // rename frame_%d
        final files = segDir.listSync().whereType<File>().where((f) => p.basename(f.path).startsWith('frame_'));
        final sortedFiles = files.toList()..sort((a, b) => a.path.compareTo(b.path));
        for (final f in sortedFiles) {
          // padLeft(4, '0') => 避免後面排序有問題
          final newName = 'f_${imageIndex.toString().padLeft(4, '0')}${p.extension(f.path)}';
          final newPath = p.join(segDir.path, newName);
          f.renameSync(newPath);
          imageIndex++;
        }

        print('完成 seg_$i，exit=$code');
      } catch (e) {
        print('啟動 ffmpeg 失敗: $e');
      }

      // 計劃擷取時間（理想值）
      final plannedTimes = <int>[];
      for (
        int t = r.start.inMilliseconds;
        t <= (r.end?.inMilliseconds ?? r.start.inMilliseconds);
        t += r.interval.inMilliseconds
      ) {
        plannedTimes.add(t);
      }

      meta.segments.add(
        CapturedSegment(
          index: i,
          start: r.start,
          end: r.end,
          interval: r.interval,
          outputDir: segDir.path,
          plannedCaptureTimesMs: plannedTimes,
        ),
      );
    }

    // for (var rule in newRules) {
    //   final segDir = Directory(p.join(projectDir.path, "seg_$segmentIndex"));
    //   if (!segDir.existsSync()) segDir.createSync();
    //
    //   final crop = "crop=${rule.rect.width}:${rule.rect.height}:${rule.rect.left}:${rule.rect.top}";
    //   final fps = 1 / (rule.interval.inMilliseconds / 1000.0);
    //
    //   final cmd =
    //       '-ss ${rule.start.inSeconds} -i "$videoPath" -vf "$crop,fps=$fps" "${p.join(segDir.path, "frame_%04d.png")}"';
    //
    //   // ffmpeg command
    //   final args = ["-ss", start.inSeconds.toString(), "-i", inputPath, "-vf", "$crop,fps=$fps", outputPattern];
    //
    //   print("Running ffmpeg: $cmd");
    //
    //   // await FFmpegKit.execute(cmd);
    //   final process = await Process.start("ffmpeg", args);
    //
    //   // 監聽 stdout/stderr
    //   process.stdout.transform(SystemEncoding().decoder).listen((data) {
    //     _addLog(data);
    //   });
    //   process.stderr.transform(SystemEncoding().decoder).listen((data) {
    //     _addLog(data);
    //   });
    //
    //   final exitCode = await process.exitCode;
    //   print("ffmpeg 完成，exit code: $exitCode");
    //
    //   meta["segments"].add({"rule": rule.toJson(), "output_dir": segDir.path});
    //
    //   segmentIndex++;
    // }

    final metaFile = File(p.join(projectDir.path, 'meta.json'));
    // await metaFile.writeAsString(jsonEncode(meta));
    await metaFile.writeAsString(const JsonEncoder.withIndent(' ').convert(meta.toJson()));
    print('Meta saved: ${metaFile.path}');
    print('擷取完成，輸出到 ${projectDir.path}');
    return meta;
  }

  /// 詳細請參考 [runCapture]
  Future<String> getMetaFilePath(String outputDir) async {
    final projectDir = Directory(p.join(outputDir, 'captures'));
    final metaFilePath = p.join(projectDir.path, 'meta.json');
    return metaFilePath;
  }

  /// 詳細請參考 [runCapture]
  Future<String> getCaptureOutputDir(String outputDir) async {
    final projectDir = Directory(p.join(outputDir, 'captures'));
    return projectDir.path;
  }

  Future<List<String>> _buildFfmpegArgs({
    required String inputPath,
    required String outputPattern, // e.g. /path/seg_0/frame_%04d.png
    required Duration start,
    required Duration interval,
    required Rect rectVideoPx,
  }) async {
    // 影片像素 → 整數
    final x = rectVideoPx.left.round();
    final y = rectVideoPx.top.round();
    final w = rectVideoPx.width.round();
    final h = rectVideoPx.height.round();

    final fps = 1 / (interval.inMilliseconds / 1000.0); // 例: 1/0.2 = 5
    return [
      '-ss',
      start.inMilliseconds >= 0 ? (start.inMilliseconds / 1000).toStringAsFixed(3) : '0',
      '-i',
      inputPath,
      '-vf',
      'crop=$w:$h:$x:$y,fps=$fps',
      outputPattern,
    ];
  }

  // 尋找「距離目前播放時間最近且中間沒有停止點」的 rule
  CaptureRule? nearestRuleFor(Duration pos) {
    if (_rules.isEmpty) return null;
    CaptureRule? best;
    int bestAbs = 1 << 30;
    for (final r in _rules) {
      if (_hasStopBetween(r.start, pos)) continue; // 有停止點擋住則跳過
      final diff = (r.start.inMilliseconds - pos.inMilliseconds).abs();
      if (diff < bestAbs) {
        bestAbs = diff;
        best = r;
      }
    }
    return best;
  }

  /// 是否在 a 與 b 之間有停止點（嚴格介於之間；端點不算）
  bool _hasStopBetween(Duration a, Duration b) {
    if (_stopPoints.isEmpty) return false;
    final lo = a <= b ? a : b;
    final hi = a <= b ? b : a;
    for (final s in _stopPoints) {
      if (s > lo && s < hi) return true;
    }
    return false;
  }

  /// For 乾燥花
  void addRulesAndStopPointsForDebug() {
    _rules.clear();
    _stopPoints.clear();

    _rules.addAll([
      CaptureRule.fromJson({
        'start_ms': 23859,
        'end_ms': null,
        'interval_ms': 3322,
        'rect': {'x': 0, 'y': 155, 'w': 1920, 'h': 260},
      }),
      CaptureRule.fromJson({
        'start_ms': 119641,
        'end_ms': null,
        'interval_ms': 3322,
        'rect': {'x': 0, 'y': 155, 'w': 1920, 'h': 260},
      }),
      CaptureRule.fromJson({
        'start_ms': 209646,
        'end_ms': null,
        'interval_ms': 3322,
        'rect': {'x': 0, 'y': 155, 'w': 1920, 'h': 260},
      }),
    ]);
    _stopPoints.addAll([
      Duration(milliseconds: 107752),
      Duration(milliseconds: 202981),
      Duration(milliseconds: 266308),
    ]);
  }
}
