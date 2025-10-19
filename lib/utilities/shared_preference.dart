import 'package:shared_preferences/shared_preferences.dart';

const _gridLinesKey = 'gridLines';

class MySharedPreference {
  MySharedPreference._(this._storage);

  static MySharedPreference? _instance;

  static MySharedPreference get instance => _instance!;

  static Future<void> ensureInitialized() async {
    _instance ??= MySharedPreference._(await SharedPreferences.getInstance());
  }

  final SharedPreferences _storage;

  // region
  Future<void> setGridLines(List<int> gridLines) async {
    _storage.setString(_gridLinesKey, gridLines.join(','));
  }

  Future<List<int>?> getGridLines() async {
    try {
      final str = _storage.getString(_gridLinesKey);
      if (str == null || str.isEmpty) {
        return null;
      }
      return str.split(',').map((e) => int.parse(e)).whereType<int>().toList();
    } catch (e) {
      return null;
    }
  }

  // endregion
}
