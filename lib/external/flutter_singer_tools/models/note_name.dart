// 升D調	D-sharp 或 D♯
// 降D調	D-flat 或 D♭
/// 注意，要照頻率順序排列音符名稱，因 [compareTo] 會根據 [index] 來比較大小。
enum NoteName implements Comparable<NoteName> {
  c,
  cSharp,
  d,
  dSharp,
  e,
  f,
  fSharp,
  g,
  gSharp,
  a,
  aSharp,
  b;

  /// 照頻率順序排列的所有音符名稱。
  static const List<NoteName> allValues = [
    c,
    cSharp,
    d,
    dSharp,
    e,
    f,
    fSharp,
    g,
    gSharp,
    a,
    aSharp,
    b,
  ];

  String get displayName {
    return switch (this) {
      NoteName.c => 'C',
      NoteName.cSharp => 'C#',
      NoteName.d => 'D',
      NoteName.dSharp => 'D#',
      NoteName.e => 'E',
      NoteName.f => 'F',
      NoteName.fSharp => 'F#',
      NoteName.g => 'G',
      NoteName.gSharp => 'G#',
      NoteName.a => 'A',
      NoteName.aSharp => 'A#',
      NoteName.b => 'B',
    };
  }

  @override
  int compareTo(NoteName other) {
    return index.compareTo(other.index);
  }

  bool isBetween(NoteName? minNote, NoteName? maxNote) {
    if (minNote == null && maxNote == null) {
      return true; // 沒有範圍限制
    }
    if (minNote == null) {
      return compareTo(maxNote!) <= 0; // 只限制上限
    }
    if (maxNote == null) {
      return compareTo(minNote) >= 0; // 只限制下限
    }
    return compareTo(minNote) >= 0 && compareTo(maxNote) <= 0; // 同時限制上下限
  }
}

// ## 🎵 **Note（音符 / 音高）**
//
// - **定義**：音樂中最基本的單位，代表一個特定的音高（Pitch），例如：C、D、E、F、G、A、B。
//
// - 每個 note 都可以有不同的**八度**（如 C3、C4），代表頻率的高低。
//
// - 音符也可以指**音符符號**，在樂譜上標示音的長度與高低。
//
//
// 例如：
//
// - **C4**：中央 C，頻率約 261.63 Hz。
//
// - **A4**：440 Hz，音樂標準音。
//
//
// ---
//
// ## 🎼 **Major Key（大調）**
//
// - **定義**：一種**音階系統**（scale）和**調性（key）**，它的音階由七個音組成，結構是：
//
//
// > 全音 - 全音 - 半音 - 全音 - 全音 - 全音 - 半音
//
// 例如：
//
// - **C 大調（C Major）**：C, D, E, F, G, A, B
//
// - 沒有升降記號（♯或♭）
//
//
// 其他例子：
//
// - **G 大調**：G, A, B, C, D, E, F♯
//
// - **F 大調**：F, G, A, B♭, C, D, E
//
//
// ---
//
// ## ✅ **關係**
//
// - **Note** 是單一的音高
//
// - **Major Key** 是基於某個 Note 為**主音**（tonic）形成的音階，並定義整首曲子使用的音組合。
//
// - 例如：在 C 大調中，C 是主音，七個 note 構成這個 key 的音階。
//
//
// ---
//
// 如果你要做程式上的實作，可以把：
//
// - Note：當成單音或音高對應的頻率
//
// - Major Key：當成某個起點（如 C）和一組間隔關係，來產生完整音階。
