import 'package:open_file/open_file.dart';

class MyOpenFile {
  MyOpenFile._();

  static Future<void> open(String filePath) async {
    await OpenFile.open(filePath);
  }
}