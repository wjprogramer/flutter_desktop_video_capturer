import 'package:shared_preferences/shared_preferences.dart';

class MySharedPreference {
  MySharedPreference._(this._storage);

  static MySharedPreference? _instance;

  static MySharedPreference get instance => _instance!;

  static Future<void> ensureInitialized() async {
    _instance ??= MySharedPreference._(await SharedPreferences.getInstance());
  }

  final SharedPreferences _storage;
}