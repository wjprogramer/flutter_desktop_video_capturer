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
  final peaks = <int>[];
  final minDist = (h / 20).floor();
  final thr = _percentile(sm, 0.92);
  for (int y = 1; y < h - 1; y++) {
    if (sm[y] > thr && sm[y] >= sm[y - 1] && sm[y] >= sm[y + 1]) {
      if (peaks.isNotEmpty && (y - peaks.last) < minDist) {
        if (sm[y] > sm[peaks.last]) peaks[peaks.length - 1] = y;
      } else {
        peaks.add(y);
      }
    }
  }
  peaks.sort();
  if (peaks.length != 10) {
    // 等距回歸近似補齊/裁切
    final a = peaks.isNotEmpty ? peaks.first.toDouble() : h * 0.15;
    final b = peaks.length > 1 ? (peaks.last - a) / math.max(1, (peaks.length - 1)) : h / 12.0;
    final approx = [for (int k = 0; k < 10; k++) (a + b * k).round()];
    return approx.map((e) => e.clamp(0, h - 1)).toList();
  }
  return peaks;
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
