import 'dart:convert';

import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/tuning_fork/enums.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

import 'tuning_fork_controller.dart';

class TuningForkControllerMobile implements TuningForkController {
  final WebViewController? controller;
  final WebviewController? windowsController;

  TuningForkControllerMobile(this.controller, this.windowsController);

  bool _isPlaying = false;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Future<void> setFrequency(double freq) async {
    await _runJavaScript('setFrequency(${freq.toInt()})');
  }

  @override
  Future<void> setVolume(double volume) async {
    await _runJavaScript('setVolume(${volume.toStringAsFixed(2)})');
  }

  @override
  Future<void> setWaveform(Waveform type) async {
    await _runJavaScript('setWaveform("${type.code}")');
  }

  @override
  Future<void> play({double frequency = 440, double volume = 0.1, Waveform waveform = Waveform.sine}) async {
    final json = jsonEncode({
      'frequency': frequency.toInt(),
      'volume': volume.toStringAsFixed(3),
      'waveform': waveform.code,
    });
    await _runJavaScript('play($json)');
    _isPlaying = true;
  }

  @override
  Future<void> stop() async {
    await _runJavaScript('stop()');
    _isPlaying = false;
  }

  Future<void> _runJavaScript(String javaScript) async {
    if (windowsController != null) {
      await windowsController!.executeScript(javaScript);
    } else {
      await controller?.runJavaScript(javaScript);
    }
  }
}

TuningForkController buildTuningForkController({
  WebViewController? webController,
  WebviewController? windowsWebController,
}) {
  // if (webController == null) {
  //   throw Exception('WebViewController is required on mobile');
  // }
  return TuningForkControllerMobile(webController, windowsWebController);
}
