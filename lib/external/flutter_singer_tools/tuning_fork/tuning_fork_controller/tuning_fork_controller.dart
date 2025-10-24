import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/tuning_fork/enums.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

// import 'tuning_fork_controller_stub.dart'
// if (dart.library.web) 'tuning_fork_controller_web.dart'
// if (dart.library.js) 'tuning_fork_controller_web.dart'
// if (dart.library.io) 'tuning_fork_controller_io.dart';

import 'tuning_fork_controller_web.dart' if (dart.library.io) 'tuning_fork_controller_io.dart';

abstract class TuningForkController {
  factory TuningForkController({WebViewController? webController, WebviewController? windowsWebController}) =>
      buildTuningForkController(webController: webController, windowsWebController: windowsWebController);

  bool get isPlaying;

  Future<void> setFrequency(double freq);

  Future<void> setVolume(double volume);

  Future<void> setWaveform(Waveform type);

  Future<void> play({double frequency = 440, double volume = 0.1, Waveform waveform = Waveform.sine});

  Future<void> stop();
}
