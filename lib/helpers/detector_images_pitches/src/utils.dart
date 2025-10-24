double getPitchLinesAvgGap(List<int> pitchLinesY) {
  if (pitchLinesY.length < 2) return 1.0;
  double sum = 0;
  for (int i = 1; i < pitchLinesY.length; i++) {
    sum += (pitchLinesY[i] - pitchLinesY[i - 1]).toDouble();
  }
  return sum / (pitchLinesY.length - 1);
}

int getPitchIndex(List<int> gridLinesY, double y0, double y1) {
  // 以區段的中心判斷（你保證不跨兩線，中心就足夠代表「哪邊面積多」）
  final c = (y0 + y1) / 2.0;
  if (gridLinesY.isEmpty) return 0;

  // 平均線距與半格
  final double avgGap = getPitchLinesAvgGap(gridLinesY);
  final halfGap = avgGap / 2.0;

  final L = gridLinesY;
  final n = L.length;

  // ---- 底部（大於最後一條）→ 負號向下延伸：-1, -2, ...
  if (c >= L.last) {
    final d = (c - L.last);
    final halfSteps = (d / halfGap).floor();
    // 緊貼最後一條但在其下方半格 → -1
    return -(halfSteps + 1);
  }

  // ---- 頂部（小於第一條）→ 往上延伸：18, 19, 20, ...
  if (c < L.first) {
    final d = (L.first - c);
    final halfSteps = (d / halfGap).floor();
    // 內部最上段(i=0)的索引是 16/17，所以上方從 18 開始遞增
    return 2 * (n - 1) + halfSteps;
  }

  // ---- 落在相鄰兩條線中間：找 i 使得 L[i] <= c < L[i+1]
  int i = 0;
  int lo = 0, hi = n - 2;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (c < L[mid]) {
      hi = mid - 1;
    } else if (c >= L[mid + 1]) {
      lo = mid + 1;
    } else {
      i = mid;
      break;
    }
  }

  final midPt = (L[i] + L[i + 1]) / 2.0;

  // 由底往上編號：區段 (L[i], L[i+1]) 的「自底序號」s = 0 對應最底段(201~222)
  final sFromBottom = (n - 2) - i; // i=8 → s=0, i=7 → s=1, ...
  final baseEven = 2 * sFromBottom; // 底段：0/1；再上去：2/3；再上去：4/5…

  // 下半（靠近較大的 y，即較「下面」那條線）→ 偶數；上半 → 奇數
  return (c < midPt) ? (baseEven + 1) : baseEven;
}