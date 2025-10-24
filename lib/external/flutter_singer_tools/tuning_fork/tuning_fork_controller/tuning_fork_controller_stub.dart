import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/tuning_fork/tuning_fork_controller/tuning_fork_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

TuningForkController buildTuningForkController({
  WebViewController? webController,
}) {
  throw UnsupportedError(
    'Cannot create a client without dart:html or dart:io.',
  );
}
