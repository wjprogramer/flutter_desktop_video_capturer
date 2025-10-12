import 'dart:math' as math;

import 'package:image/image.dart' as img;

class DetectedBar {
  final double xCenter; // 0..1
  final double x0; // 0..1
  final double x1; // 0..1
  final double yUnits; // 以灰線間距為 1，由下往上；可為負
  final double yNorm; // 投影到 0..1（夾在 0..1）
  final double w;
  final double h;

  DetectedBar({
    required this.xCenter,
    required this.x0,
    required this.x1,
    required this.yUnits,
    required this.yNorm,
    required this.w,
    required this.h,
  });

  Map<String, dynamic> toJson() => {
    'x_center': xCenter,
    'x0': x0,
    'x1': x1,
    'y_line_units': yUnits,
    'y_norm_0_1': yNorm,
    'w': w,
    'h': h,
  };
}

class ImageResult {
  ImageResult({
    required this.file,
    required this.width,
    required this.height,
    required this.gridLinesY,
    required this.lineSpacingPx,
    required this.bars,
  });

  final String file;

  /// 圖片的寬度
  final int width;

  /// 圖片的高度
  final int height;

  /// 上->下 10 條灰線的 y（像素）
  final List<int> gridLinesY;
  final double lineSpacingPx;
  final List<DetectedBar> bars;

  Map<String, dynamic> toJson() => {
    'file': file,
    'width': width,
    'height': height,
    'gridLinesY': gridLinesY,
    'lineSpacingPx': lineSpacingPx,
    'bars': bars.map((e) => e.toJson()).toList(),
  };
}

// ===== 核心流程 =====
Future<ImageResult> processImage(String fileName, img.Image image) async {
  final w = image.width, h = image.height;
  final mask = _blueMask(image); // 1) 藍色遮罩 + 形態學
  final boxes =
      _connectedComponents(mask, w, h) // 2) 連通元件 -> bbox 過濾
          .where((b) {
            final bw = (b[2] - b[0] + 1).toDouble();
            final bh = (b[3] - b[1] + 1).toDouble();
            final ar = bw / math.max(1, bh);
            return bw > 10 && bh > 2 && ar > 3; // 長橫條 + 去雜訊
          })
          .toList();

  final linesY = _detectGridLines(image); // 3) 找 10 條灰線（不足補齊）
  linesY.sort();
  final spacings = [for (var i = 1; i < linesY.length; i++) linesY[i] - linesY[i - 1]];
  final spacing = spacings.isEmpty ? h / 10.0 : spacings.reduce((a, b) => a + b) / spacings.length;
  final yBottom = linesY.isNotEmpty ? linesY.last.toDouble() : (h - 1).toDouble();

  final bars = <DetectedBar>[];
  for (final b in boxes) {
    final x0 = b[0].toDouble();
    final y0 = b[1].toDouble();
    final x1 = b[2].toDouble();
    final y1 = b[3].toDouble();
    final xc = (x0 + x1 + 1) / 2.0;
    final yc = (y0 + y1 + 1) / 2.0;

    final x0n = _clamp(x0 / w, 0, 1);
    final x1n = _clamp((x1 + 1) / w, 0, 1);
    final xcn = _clamp(xc / w, 0, 1);

    final yUnits = (yBottom - yc) / spacing; // 由下往上；可負
    final yNorm = _clamp(yUnits / 9.0, 0, 1);

    bars.add(
      DetectedBar(
        xCenter: xcn,
        x0: x0n,
        x1: x1n,
        yUnits: yUnits,
        yNorm: yNorm,
        w: (x1 - x0 + 1) / w,
        h: (y1 - y0 + 1) / h,
      ),
    );
  }

  bars.sort((a, b) => a.xCenter.compareTo(b.xCenter));

  return ImageResult(file: fileName, width: w, height: h, gridLinesY: linesY, lineSpacingPx: spacing, bars: bars);
}

// ====== 1) 藍色遮罩（HSV）+ 形態學閉運算 ======
List<int> _blueMask(img.Image im) {
  final w = im.width, h = im.height;
  final mask = List<int>.filled(w * h, 0);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = im.getPixel(x, y);
      final r = p.rNormalized * 255.0;
      final g = p.gNormalized * 255.0;
      final b = p.bNormalized * 255.0;
      final hsv = _rgbToHsv(r, g, b);
      final H = hsv[0], S = hsv[1], V = hsv[2];
      final isBlue = (H >= 185 && H <= 255) && S >= 0.35 && V >= 0.35;
      mask[y * w + x] = isBlue ? 1 : 0;
    }
  }
  return _morphClose(mask, w, h, 3);
}

List<int> _morphClose(List<int> mask, int w, int h, int k) {
  return _erode(_dilate(mask, w, h, k), w, h, k);
}

List<int> _dilate(List<int> mask, int w, int h, int k) {
  final out = List<int>.filled(w * h, 0);
  final r = math.max(1, k ~/ 2);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      var on = 0;
      for (int dy = -r; dy <= r && on == 0; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (int dx = -r; dx <= r; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          if (mask[yy * w + xx] != 0) {
            on = 1;
            break;
          }
        }
      }
      out[y * w + x] = on;
    }
  }
  return out;
}

List<int> _erode(List<int> mask, int w, int h, int k) {
  final out = List<int>.filled(w * h, 0);
  final r = math.max(1, k ~/ 2);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      var ok = 1;
      for (int dy = -r; dy <= r && ok == 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) {
          ok = 0;
          break;
        }
        for (int dx = -r; dx <= r; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= w) {
            ok = 0;
            break;
          }
          if (mask[yy * w + xx] == 0) {
            ok = 0;
            break;
          }
        }
      }
      out[y * w + x] = ok;
    }
  }
  return out;
}

// ====== 2) 連通元件（4-鄰域）回傳 bbox ======
List<List<int>> _connectedComponents(List<int> mask, int w, int h) {
  final labels = List<int>.filled(w * h, -1);
  final boxes = <List<int>>[]; // [x0,y0,x1,y1,area]
  int label = 0;
  final qx = List<int>.filled(w * h, 0);
  final qy = List<int>.filled(w * h, 0);

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final i = y * w + x;
      if (mask[i] == 0 || labels[i] != -1) continue;
      int head = 0, tail = 0;
      qx[tail] = x;
      qy[tail] = y;
      tail++;
      labels[i] = label;
      int minx = x, miny = y, maxx = x, maxy = y, cnt = 0;

      while (head < tail) {
        final cx = qx[head], cy = qy[head];
        head++;
        cnt++;
        const dirs = [
          [1, 0],
          [-1, 0],
          [0, 1],
          [0, -1],
        ];
        for (final d in dirs) {
          final nx = cx + d[0], ny = cy + d[1];
          if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
          final ni = ny * w + nx;
          if (mask[ni] != 0 && labels[ni] == -1) {
            labels[ni] = label;
            qx[tail] = nx;
            qy[tail] = ny;
            tail++;
            if (nx < minx) minx = nx;
            if (ny < miny) miny = ny;
            if (nx > maxx) maxx = nx;
            if (ny > maxy) maxy = ny;
          }
        }
      }
      boxes.add([minx, miny, maxx, maxy, cnt]);
      label++;
    }
  }
  return boxes;
}

// ====== 3) 灰線偵測（逐列垂直梯度投影 + 峰值） ======
List<int> _detectGridLines(img.Image im) {
  final w = im.width, h = im.height;
  // 灰階
  final gray = List<double>.filled(w * h, 0);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = im.getPixel(x, y);
      final r = p.rNormalized * 255.0;
      final g = p.gNormalized * 255.0;
      final b = p.bNormalized * 255.0;
      gray[y * w + x] = 0.299 * r + 0.587 * g + 0.114 * b;
    }
  }
  // 每列梯度能量
  final rowEnergy = List<double>.filled(h, 0);
  for (int y = 1; y < h - 1; y++) {
    double sum = 0;
    for (int x = 0; x < w; x++) {
      final a = gray[(y - 1) * w + x];
      final c = gray[(y + 1) * w + x];
      sum += (c - a).abs();
    }
    rowEnergy[y] = sum / w;
  }
  // 平滑
  final sm = List<double>.filled(h, 0);
  const k = 5;
  for (int y = 0; y < h; y++) {
    double s = 0;
    int c = 0;
    for (int t = -k; t <= k; t++) {
      final yy = y + t;
      if (yy < 0 || yy >= h) continue;
      s += rowEnergy[yy];
      c++;
    }
    sm[y] = s / (c == 0 ? 1 : c);
  }
  // 峰值
  // 產生候選峰（不使用 minDist，門檻放低）——最多取前 60 個最強者
  final cands = <int>[];
  final scores = <double>[];
  final thrCand = _percentile(sm, 0.60);
  for (int y = 1; y < h - 1; y++) {
    final v = sm[y];
    if (v > thrCand && v >= sm[y - 1] && v >= sm[y + 1]) {
      cands.add(y);
      scores.add(v);
    }
  }

  // 依能量由高到低，最多留 60 個候選
  final idx = List<int>.generate(cands.length, (i) => i);
  idx.sort((a, b) => scores[b].compareTo(scores[a]));
  final maxKeep = 60;
  final kept = idx.take(maxKeep).map((i) => cands[i]).toList()..sort();

  // 用候選線（kept）挑出最等距的 10 條
  final best10 = _pickBestArithmetic10(kept, h);
  return best10;
}

// ====== 小工具 ======
List<double> _rgbToHsv(double r, double g, double b) {
  r /= 255;
  g /= 255;
  b /= 255;
  final maxv = [r, g, b].reduce(math.max);
  final minv = [r, g, b].reduce(math.min);
  final d = maxv - minv;
  double h = 0;
  if (d != 0) {
    if (maxv == r) {
      h = ((g - b) / d + (g < b ? 6 : 0));
    } else if (maxv == g) {
      h = ((b - r) / d + 2);
    } else {
      h = ((r - g) / d + 4);
    }
    h *= 60; // 0..360
  }
  final s = maxv == 0 ? 0.0 : d / maxv; // 0..1
  final v = maxv; // 0..1
  return [h, s, v];
}

double _percentile(List<double> arr, double p) {
  final v = [...arr]..sort();
  final idx = ((p.clamp(0, 1)) * (v.length - 1)).floor();
  return v[idx];
}

double _clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// 從候選線中「挑出最等距的 10 條」
///
/// 在同一支檔案中新增一個工具函式 _pickBestArithmetic10，並在 _detectGridLines 的最後用它來挑 10 條線。
/// 如果候選不足 10 會自動用等距補齊。
List<int> _pickBestArithmetic10(List<int> cand, int h) {
  if (cand.isEmpty) {
    // 完全沒候選：給一個等距預設
    final top = (h * 0.15).round();
    final bot = (h * 0.85).round();
    final step = (bot - top) / 9.0;
    return [for (int k = 0; k < 10; k++) (top + step * k).round().clamp(1, h - 2)];
  }
  cand.sort();
  // 候選少於 10：先回歸出等距格，再「吸附」最近候選；缺的就用等距
  if (cand.length <= 10) {
    final top = cand.first, bot = cand.last;
    final step = ((bot - top) / math.max(1, cand.length - 1)).clamp(2.0, h / 8);
    final approx = [for (int k = 0; k < 10; k++) (top + step * k).round()];
    return _snapToCandidates(approx, cand, h, win: 3);
  }

  // 估計間距（候選相鄰差的中位數）
  final diffs = <int>[];
  for (int i = 1; i < cand.length; i++) diffs.add(cand[i] - cand[i - 1]);
  diffs.sort();
  final spacingGuess = diffs[diffs.length ~/ 2].toDouble().clamp(2.0, h / 6);
  final tau = math.max(2.0, spacingGuess * 0.25); // 容許誤差

  double bestCost = double.infinity;
  List<int> best = [];

  // RANSAC 風格：從候選兩點 + 假設其對應 slot (m,n) 建立等差模型 y ≈ a + b*k
  // 為控複雜度，只試少量最具代表性的 pairs
  final picks = <int>[];
  // 取頭、中、尾附近的代表性索引（避免 O(N^4)）
  for (final i in [0, (cand.length ~/ 4), (cand.length ~/ 2), (cand.length * 3 ~/ 4), cand.length - 1]) {
    if (i >= 0 && i < cand.length) picks.add(i);
  }
  final uniq = picks.toSet().toList()..sort();

  for (final ii in uniq) {
    for (final jj in uniq) {
      if (jj <= ii) continue;
      final yi = cand[ii].toDouble();
      final yj = cand[jj].toDouble();

      for (int m = 0; m < 9; m++) {
        for (int n = m + 1; n < 10; n++) {
          final b = (yj - yi) / (n - m);
          if (b < spacingGuess * 0.5 || b > spacingGuess * 1.8) continue; // 排除離譜間距
          final a = yi - b * m;

          // 生成 10 個槽位，貪婪匹配候選，計算殘差
          final slots = [for (int k = 0; k < 10; k++) a + b * k];
          final picked = _assignSlots(slots, cand, tau);
          if (picked.isEmpty) continue;

          // cost：槽位與被指派候選的 |誤差| 之和 + 罰則（未命中槽位）
          double cost = 0;
          for (int k = 0; k < 10; k++) {
            final y = picked[k];
            if (y == null) {
              cost += tau * 2; // miss 罰則
            } else {
              cost += (y - slots[k]).abs();
            }
          }
          if (cost < bestCost) {
            bestCost = cost;
            // 若某槽位沒命中，就用槽位值補；最後再做小吸附
            final base = <int>[for (int k = 0; k < 10; k++) (picked[k]?.round() ?? slots[k].round()).clamp(1, h - 2)];
            best = _snapToCandidates(base, cand, h, win: math.max(3, (b * 0.15).round()));
          }
        }
      }
    }
  }

  if (best.isNotEmpty) return best..sort();

  // 後備：用候選的首尾做等距，再吸附
  final top = cand.first, bot = cand.last;
  final step = ((bot - top) / 9.0).clamp(2.0, h / 8);
  final approx = [for (int k = 0; k < 10; k++) (top + step * k).round()];
  return _snapToCandidates(approx, cand, h, win: 4)..sort();
}

// 在每個預測 y 附近 ±win 內，吸附到最近候選（若沒有就保留原值）
List<int> _snapToCandidates(List<int> approx, List<int> cand, int h, {int win = 3}) {
  final out = <int>[];
  for (final y0 in approx) {
    final lo = (y0 - win).clamp(1, h - 2);
    final hi = (y0 + win).clamp(1, h - 2);
    int best = y0;
    int bi = _lowerBound(cand, y0);
    // 檢查 y0 附近的幾個候選
    for (final j in [bi - 2, bi - 1, bi, bi + 1, bi + 2]) {
      if (j >= 0 && j < cand.length) {
        final y = cand[j];
        if (y >= lo && y <= hi && (y - y0).abs() < (best - y0).abs()) best = y;
      }
    }
    out.add(best);
  }
  return out;
}

// 將槽位依序指派到最接近的候選（距離 > tau 視為 miss），返回每個槽位指派的 y（或 null）
List<double?> _assignSlots(List<double> slots, List<int> cand, double tau) {
  final out = List<double?>.filled(slots.length, null);
  int i = 0;
  for (int k = 0; k < slots.length; k++) {
    final target = slots[k];
    // 前進到 >= target 的候選
    while (i < cand.length - 1 && cand[i] < target) i++;
    double bestDist = double.infinity;
    double? best;
    for (final j in [i - 1, i, i + 1]) {
      if (j < 0 || j >= cand.length) continue;
      final d = (cand[j] - target).abs();
      if (d < bestDist) {
        bestDist = d;
        best = cand[j].toDouble();
      }
    }
    if (best != null && bestDist <= tau) out[k] = best;
  }
  return out;
}

int _lowerBound(List<int> a, int x) {
  int lo = 0, hi = a.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (a[mid] < x)
      lo = mid + 1;
    else
      hi = mid;
  }
  return lo;
}
