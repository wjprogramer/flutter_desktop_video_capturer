typedef ComparatorT<T> = int Function(T a, T b);

enum BoundType { open, closed }

// 可能會想要的延伸
//
// - expand(Duration by) 或 inflate(num by)：把上下界同步外擴固定量（適合數字/時間）。
// - map<U>(...)：把 Range 維持開閉語意下轉型（要小心單調性）。
// - mergeIfOverlap(List<Range<T>>)：合併重疊/相鄰的區間。
//
// 如果你提供你的實際 T 類型（int/double/DateTime 等），我可以幫你加上對應的擴充方法（例如 expand(Duration) for DateTime、或 inflate(num) for num）。

class Range<T> {
  /// null 表示 -∞
  final T? lower;
  final BoundType lowerType;

  /// null 表示 +∞
  final T? upper;
  final BoundType upperType;

  /// 用來比較 T 的大小。若未指定，且 T 是 Comparable，會自動推導。
  final ComparatorT<T>? _cmp;

  /// 是否允許在建構時把「非法順序」折算成空集合
  final bool allowEmpty;

  /// 建構子（進階）：直接給上下界與型態。一般建議用工廠方法。
  Range({
    required this.lower,
    this.lowerType = BoundType.closed,
    required this.upper,
    this.upperType = BoundType.closed,
    ComparatorT<T>? comparator,
    this.allowEmpty = true,
  }) : _cmp = comparator {
    if (!allowEmpty) {
      assert(_isOrderValid(), 'lower must be <= upper with proper openness.');
    }
  }

  /// 工廠：閉區間 [a, b]
  factory Range.closed(T a, T b, {ComparatorT<T>? comparator}) =>
      Range<T>(lower: a, lowerType: BoundType.closed, upper: b, upperType: BoundType.closed, comparator: comparator);

  /// (a, b)
  factory Range.open(T a, T b, {ComparatorT<T>? comparator}) =>
      Range<T>(lower: a, lowerType: BoundType.open, upper: b, upperType: BoundType.open, comparator: comparator);

  /// (a, b]
  factory Range.openClosed(T a, T b, {ComparatorT<T>? comparator}) =>
      Range<T>(lower: a, lowerType: BoundType.open, upper: b, upperType: BoundType.closed, comparator: comparator);

  /// [\a, b)
  factory Range.closedOpen(T a, T b, {ComparatorT<T>? comparator}) =>
      Range<T>(lower: a, lowerType: BoundType.closed, upper: b, upperType: BoundType.open, comparator: comparator);

  /// (-∞, b)
  factory Range.lessThan(T b, {ComparatorT<T>? comparator}) =>
      Range<T>(lower: null, upper: b, upperType: BoundType.open, comparator: comparator);

  /// (-∞, b]
  factory Range.lessThanOrEqual(T b, {ComparatorT<T>? comparator}) =>
      Range<T>(lower: null, upper: b, upperType: BoundType.closed, comparator: comparator);

  /// (a, +∞)
  factory Range.greaterThan(T a, {ComparatorT<T>? comparator}) =>
      Range<T>(lower: a, lowerType: BoundType.open, upper: null, comparator: comparator);

  /// [\a, +∞)
  factory Range.atLeast(T a, {ComparatorT<T>? comparator}) =>
      Range<T>(lower: a, lowerType: BoundType.closed, upper: null, comparator: comparator);

  /// (-∞, +∞)
  factory Range.all({ComparatorT<T>? comparator}) =>
      Range<T>(lower: null, upper: null, comparator: comparator);

  bool get hasLower => lower != null;
  bool get hasUpper => upper != null;

  // ---- 基礎比較工具 ----

  ComparatorT<T> get _comparator {
    if (_cmp != null) return _cmp;
    // 嘗試用 Comparable
    return (a, b) => (a as Comparable).compareTo(b as Object);
  }

  bool _isOrderValid() {
    if (!hasLower || !hasUpper) return true; // 有一邊無界一定合法
    final c = _comparator(lower as T, upper as T);
    if (c < 0) return true;      // lower < upper
    if (c > 0) return false;     // lower > upper → 非法
    // lower == upper：只有當兩邊都是 open 才是空（合法但 empty）；其餘合法
    return true;
  }

  /// 是否為空集合，例如 (a, a) 這種純開區間
  bool get isEmpty {
    if (!hasLower || !hasUpper) return false;
    final c = _comparator(lower as T, upper as T);
    if (c < 0) return false;
    if (c > 0) return true;
    // c == 0：端點相等
    // 只要任一端是「開」，就不包含該點 → 空
    return lowerType == BoundType.open || upperType == BoundType.open;
  }

  // ---- 內容檢查 ----

  bool contains(T value) {
    if (!isLowerSatisfied(value)) return false;
    if (!isUpperSatisfied(value)) return false;
    return !isEmpty;
  }

  bool isLowerSatisfied(T v) {
    if (!hasLower) return true;
    final c = _comparator(v, lower as T);
    if (lowerType == BoundType.closed) {
      return c >= 0;
    } else {
      return c > 0;
    }
  }

  bool isUpperSatisfied(T v) {
    if (!hasUpper) return true;
    final c = _comparator(v, upper as T);
    if (upperType == BoundType.closed) {
      return c <= 0;
    } else {
      return c < 0;
    }
  }

  // ---- Range 與 Range 關係 ----

  /// 完全大於：A 的起點嚴格大於 B 的終點（不含相等）
  bool completelyGreaterThan(Range<T> other) {
    if (!hasLower) return false;        // -∞ 不可能完全大於
    if (!other.hasUpper) return false;  // 比不過 +∞
    final c = _comparator(lower as T, other.upper as T);
    if (c > 0) return true;
    if (c < 0) return false;
    // 相等 → 不算「完全」大於
    return false;
  }

  /// 完全小於：A 的終點嚴格小於 B 的起點（不含相等）
  bool completelyLessThan(Range<T> other) {
    if (!hasUpper) return false;
    if (!other.hasLower) return false;
    final c = _comparator(upper as T, other.lower as T);
    if (c < 0) return true;
    if (c > 0) return false;
    // 相等 → 不算「完全」小於
    return false;
  }

  /// 是否重疊（有任意交集，包含端點重合且兩端皆閉的情形）
  bool overlaps(Range<T> other) {
    if (isEmpty || other.isEmpty) return false;
    // 若 A 完全小於 B 或 A 完全大於 B → 不重疊
    if (completelyLessThan(other) || completelyGreaterThan(other)) return false;

    // 端點相等需要看開閉
    // A.upper == B.lower
    if (hasUpper && other.hasLower) {
      final c = _comparator(upper as T, other.lower as T);
      if (c == 0 && (upperType == BoundType.open || other.lowerType == BoundType.open)) {
        // 至少一邊開 → 不重疊（相鄰）
        return false;
      }
    }
    // B.upper == A.lower
    if (other.hasUpper && hasLower) {
      final c = _comparator(other.upper as T, lower as T);
      if (c == 0 && (other.upperType == BoundType.open || lowerType == BoundType.open)) {
        return false;
      }
    }
    return true;
  }

  /// 是否互斥（無交集）：等價於 !overlaps
  bool isDisjoint(Range<T> other) => !overlaps(other);

  /// 是否相鄰（剛好貼齊、無重疊）
  bool isAdjacentTo(Range<T> other) {
    if (isEmpty || other.isEmpty) return false;
    // A.upper == B.lower 且至少一邊開
    if (hasUpper && other.hasLower) {
      final c = _comparator(upper as T, other.lower as T);
      if (c == 0 && (upperType == BoundType.open || other.lowerType == BoundType.open)) {
        return true;
      }
    }
    // 或 B.upper == A.lower 且至少一邊開
    if (other.hasUpper && hasLower) {
      final c = _comparator(other.upper as T, lower as T);
      if (c == 0 && (other.upperType == BoundType.open || lowerType == BoundType.open)) {
        return true;
      }
    }
    return false;
  }

  /// 交集（可能為空 Range）
  Range<T> intersection(Range<T> other) {
    // 取較大的下界
    final newLowerData = _maxLower(this, other);
    // 取較小的上界
    final newUpperData = _minUpper(this, other);

    final result = Range<T>(
      lower: newLowerData.$1,
      lowerType: newLowerData.$2,
      upper: newUpperData.$1,
      upperType: newUpperData.$2,
      comparator: _cmp ?? other._cmp,
    );

    // 正規化：若違序或純開同點 → 空
    if (!result._isOrderValid()) {
      return Range<T>(
        lower: lower,
        upper: lower,
        lowerType: BoundType.open,
        upperType: BoundType.open,
        comparator: _cmp ?? other._cmp,
      );
    }
    if (result.isEmpty) return result;
    // 檢查邊界同值但開閉造成空集
    if (result.hasLower && result.hasUpper) {
      final c = _comparator(result.lower as T, result.upper as T);
      if (c == 0 && result.lowerType == BoundType.open && result.upperType == BoundType.open) {
        return result;
      }
    }
    return result;
  }

  /// 跨度（最小外接範圍，不要求連接/相鄰，單純取 minLower ~ maxUpper）
  Range<T> span(Range<T> other) {
    final newLowerData = _minLower(this, other);
    final newUpperData = _maxUpper(this, other);
    return Range<T>(
      lower: newLowerData.$1,
      lowerType: newLowerData.$2,
      upper: newUpperData.$1,
      upperType: newUpperData.$2,
      comparator: _cmp ?? other._cmp,
    );
  }

  /// 將單一值限制在本 Range 內（若值在外面，回傳最靠近的端點；無界端點則直接回原值）
  T clamp(T value) {
    T v = value;
    if (hasLower) {
      final c = _comparator(v, lower as T);
      if (c < 0 || (c == 0 && lowerType == BoundType.open)) {
        v = lower as T;
      }
    }
    if (hasUpper) {
      final c = _comparator(v, upper as T);
      if (c > 0 || (c == 0 && upperType == BoundType.open)) {
        v = upper as T;
      }
    }
    return v;
  }

  // ---- 下/上界比較輔助（含開閉）----

  /// 回傳較大的下界（值相等時：closed 優於 open）
  (T?, BoundType) _maxLower(Range<T> a, Range<T> b) {
    if (!a.hasLower) return (b.lower, b.lowerType);
    if (!b.hasLower) return (a.lower, a.lowerType);
    final c = _comparator(a.lower as T, b.lower as T);
    if (c > 0) return (a.lower, a.lowerType);
    if (c < 0) return (b.lower, b.lowerType);
    // 同值：closed 代表包含更多 → 取 closed
    return (a.lower, a.lowerType == BoundType.closed || b.lowerType == BoundType.closed
        ? BoundType.closed
        : BoundType.open);
  }

  /// 回傳較小的上界（值相等時：closed 優於 open）
  (T?, BoundType) _minUpper(Range<T> a, Range<T> b) {
    if (!a.hasUpper) return (b.upper, b.upperType);
    if (!b.hasUpper) return (a.upper, a.upperType);
    final c = _comparator(a.upper as T, b.upper as T);
    if (c < 0) return (a.upper, a.upperType);
    if (c > 0) return (b.upper, b.upperType);
    return (a.upper, a.upperType == BoundType.closed || b.upperType == BoundType.closed
        ? BoundType.closed
        : BoundType.open);
  }

  /// 回傳較小的下界
  (T?, BoundType) _minLower(Range<T> a, Range<T> b) {
    if (!a.hasLower) return (a.lower, a.lowerType);
    if (!b.hasLower) return (b.lower, b.lowerType);
    final c = _comparator(a.lower as T, b.lower as T);
    if (c < 0) return (a.lower, a.lowerType);
    if (c > 0) return (b.lower, b.lowerType);
    // 同值：取「更開」的那個會擴大跨度嗎？span 想要外接，應選 open? 但外接應選包含更多者 → closed。
    return (a.lower, a.lowerType == BoundType.closed || b.lowerType == BoundType.closed
        ? BoundType.closed
        : BoundType.open);
  }

  /// 回傳較大的上界
  (T?, BoundType) _maxUpper(Range<T> a, Range<T> b) {
    if (!a.hasUpper) return (a.upper, a.upperType);
    if (!b.hasUpper) return (b.upper, b.upperType);
    final c = _comparator(a.upper as T, b.upper as T);
    if (c > 0) return (a.upper, a.upperType);
    if (c < 0) return (b.upper, b.upperType);
    return (a.upper, a.upperType == BoundType.closed || b.upperType == BoundType.closed
        ? BoundType.closed
        : BoundType.open);
  }

  @override
  String toString() {
    // 無界端一律用開括號
    final lb = hasLower
        ? (lowerType == BoundType.closed ? '[' : '(')
        : '('; // -∞ → '('

    final ub = hasUpper
        ? (upperType == BoundType.closed ? ']' : ')')
        : ')'; // +∞ → ')'

    final l = hasLower ? '$lower' : '-∞';
    final u = hasUpper ? '$upper' : '+∞';
    return '$lb$l, $u$ub';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Range<T> &&
        other.lower == lower &&
        other.upper == upper &&
        other.lowerType == lowerType &&
        other.upperType == upperType;
  }

  @override
  int get hashCode => Object.hash(lower, upper, lowerType, upperType);
}
