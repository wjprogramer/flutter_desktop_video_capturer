import 'dart:io';

import 'package:path_provider/path_provider.dart' as path_provider;

class MyPathProvider {
  MyPathProvider._();

  static Future<Directory> getAppDocsDir() {
    return path_provider.getApplicationDocumentsDirectory();
  }

  static Future<Directory> getAppDir() {
    return path_provider.getApplicationSupportDirectory();
  }
}