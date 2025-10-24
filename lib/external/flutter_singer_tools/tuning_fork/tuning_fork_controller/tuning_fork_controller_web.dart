import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/tuning_fork/enums.dart';
import 'package:web/web.dart' as web;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

import 'tuning_fork_controller.dart';

TuningForkController buildTuningForkController({
  WebViewController? webController,
  WebviewController? windowsWebController,
}) {
  if (webController != null) {
    throw Exception('WebViewController is not used in web implementation');
  }
  return TuningForkControllerWeb();
}

class TuningForkControllerWeb implements TuningForkController {
  web.AudioContext? _ctx;
  web.OscillatorNode? _osc;
  web.GainNode? _gain;

  double _frequency = 440;
  double _volume = 0.1;
  String _waveform = 'sine';

  TuningForkControllerWeb() {
    _ctx = web.AudioContext();
  }

  @override
  bool get isPlaying => _osc != null && _osc!.type != 'null';

  @override
  Future<void> setFrequency(double freq) async {
    _frequency = freq;
    _osc?.frequency.setValueAtTime(freq, _ctx!.currentTime);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    _gain?.gain.setValueAtTime(volume, _ctx!.currentTime);
  }

  @override
  Future<void> setWaveform(Waveform type) async {
    _waveform = type.code;
    if (_osc != null) {
      await stop();
      await play();
    }
  }

  @override
  Future<void> play({double frequency = 440, double volume = 0.1, Waveform waveform = Waveform.sine}) async {
    stop();

    _osc = _ctx!.createOscillator();
    _gain = _ctx!.createGain();

    _osc!.type = _waveform;
    _osc!.frequency.setValueAtTime(_frequency, _ctx!.currentTime);

    _gain!.gain.setValueAtTime(_volume, _ctx!.currentTime);
    _osc!.connect(_gain!)?.connect(_ctx!.destination);
    _osc!.start();
  }

  @override
  Future<void> stop() async {
    _osc?.stop();
    _osc?.disconnect();
    _gain?.disconnect();
    _osc = null;
    _gain = null;
  }
}
