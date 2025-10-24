import 'dart:io';

import 'package:flutter_desktop_video_capturer/third_party/path_provider/path_provider.dart';
import 'package:path/path.dart' as path_pkg;

class FileStructureUtility {
  FileStructureUtility._();

  /// 每次啟動有可能需要還原使用者上次操作，或是根據情況考慮刪除
  static Future<Directory> getTempDir() async {
    final appDir = await MyPathProvider.getAppDir();
    final tempDir = Directory(path_pkg.join(appDir.path, 'temp'));
    await tempDir.create(recursive: true);
    return tempDir;
  }

  /// 建立「執行影片截圖」的臨時資料夾
  static Future<Directory> generateTempVideoCaptureDir(String taskId) async {
    final tempDir = await getTempDir();
    final newSubDir = Directory(path_pkg.join(tempDir.path, 'video_capture_tasks', taskId));
    await newSubDir.create(recursive: true);
    return newSubDir;
  }
}