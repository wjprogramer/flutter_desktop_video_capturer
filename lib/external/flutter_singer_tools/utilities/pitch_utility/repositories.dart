import 'dart:math';

import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/models/note_name.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer_tools/models/pitch_name.dart';

class PitchNamesRepository {
  PitchNamesRepository._() {
    _initPitchNames();
  }

  factory PitchNamesRepository() => _instance;

  static final PitchNamesRepository _instance = PitchNamesRepository._();

  /// 八度列表，值: 0 ~ 9
  static final List<int> _octaves = List.generate(10, (index) => index);

  static const List<NoteName> _noteNames = NoteName.allValues;

  /// 音高名稱列表，由 [_initPitchNames] 初始化
  final List<List<PitchName>> _pitchNames = [];

  void _initPitchNames() {
    const int minOctave = 0;
    const int maxOctave = 9;
    const double baseFrequency = 261.63; // 中央C (C4)
    const int baseMidi = 60; // C4 = MIDI 60

    for (int noteIndex = 0; noteIndex < _noteNames.length; noteIndex++) {
      final List<PitchName> octaveFrequencies = [];
      final NoteName noteName = _noteNames[noteIndex];

      for (int octave = minOctave; octave <= maxOctave; octave++) {
        final midi = (octave + 1) * 12 + noteIndex; // octave +1 對應 MIDI
        final frequency = baseFrequency * pow(2, (midi - baseMidi) / 12);
        final semitoneDiff = midi - baseMidi; // 與 C4 的半音差

        octaveFrequencies.add(PitchName(
          frequency,
          semitoneDiff.toDouble(),
          noteName: noteName,
          octave: octave,
        ));
      }

      _pitchNames.add(octaveFrequencies);
    }
  }

  List<int> getOctaves() {
    return _octaves.toList();
  }

  List<NoteName> getNoteNames() {
    return _noteNames.toList();
  }

  List<List<PitchName>> getPitchNames() {
    // clone the list to avoid modifying the original
    return _pitchNames.map((octaveFrequencies) {
      return octaveFrequencies.map((pitchName) {
        return pitchName.copyWith();
      }).toList();
    }).toList();
  }

  List<PitchName> getPitchNamesList({
    bool isDesc = false,
    PitchName? minPitchName,
    PitchName? maxPitchName,
    double? minFrequency,
    double? maxFrequency,
  }) {
    List<PitchName> pitchNames = _pitchNames.expand((octaveFrequencies) => octaveFrequencies).toList();

    // Filter the pitch names based on min and max pitch names
    if (minPitchName != null || maxPitchName != null) {
      pitchNames = pitchNames.where((pitchName) {
        final isAfterMin = minPitchName == null || pitchName >= minPitchName;
        final isBeforeMax = maxPitchName == null || pitchName <= maxPitchName;
        return isAfterMin && isBeforeMax;
      }).toList();
    }

    // Filter the pitch names based on min and max frequency
    if (minFrequency != null || maxFrequency != null) {
      pitchNames = pitchNames.where((pitchName) {
        final isAboveMin = minFrequency == null || pitchName.value >= minFrequency;
        final isBelowMax = maxFrequency == null || pitchName.value <= maxFrequency;
        return isAboveMin && isBelowMax;
      }).toList();
    }

    // Sort the pitch names based on the isDesc flag
    pitchNames.sort((a, b) => isDesc ? b.value.compareTo(a.value) : a.value.compareTo(b.value));

    return pitchNames;
  }
}
