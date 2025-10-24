enum Waveform {
  sine,
  square,
  triangle,
  sawtooth;

  String get code => switch (this) {
    Waveform.sine => 'sine',
    Waveform.square => 'square',
    Waveform.triangle => 'triangle',
    Waveform.sawtooth => 'sawtooth',
  };

  String getDisplayName() => switch (this) {
    Waveform.sine => 'waveform_sine',
    Waveform.square => 'waveform_square',
    Waveform.triangle => 'waveform_triangle',
    Waveform.sawtooth => 'waveform_sawtooth',
  };

  double get limitMaxVolume => switch (this) {
    Waveform.sine => 1,
    Waveform.square => 0.01,
    Waveform.triangle => 0.03,
    Waveform.sawtooth => 0.015,
  };
}
