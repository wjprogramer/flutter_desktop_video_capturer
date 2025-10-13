import 'dart:math' as math;

import 'note_name.dart';

class PitchName implements Comparable<PitchName> {
  PitchName(this.value, this.diff, {required this.noteName, this.octave = 0});

  /// 音名，ex: C, C#
  final NoteName noteName;

  /// 八度
  final int octave;

  /// 頻率，unit: Hz
  final double value;

  final double diff;

  factory PitchName.fromNoteOctave(NoteName noteName, int octave) {
    const baseFrequency = 261.63; // 中央C (C4) 的頻率
    const baseMidi = 60; // C4 = MIDI 60
    final midi = (octave + 1) * 12 + noteName.index; // octave +1 對應 MIDI
    final frequency = baseFrequency * math.pow(2.0, (midi - baseMidi) / 12);
    final semitoneDiff = midi - baseMidi; // 與 C4 的半音差

    return PitchName(frequency, semitoneDiff.toDouble(), noteName: noteName, octave: octave);
  }

  factory PitchName.fromFrequency(double frequency) {
    if (frequency <= 0) {
      throw ArgumentError('Frequency must be greater than zero.');
    }

    const baseFrequency = 261.63; // 中央C (C4) 的頻率
    const baseMidi = 60; // C4 = MIDI 60
    final midi = (12 * math.log(frequency / baseFrequency) / math.log(2)).round() + baseMidi;
    final octave = (midi ~/ 12) - 1; // octave +1 對應 MIDI
    final noteIndex = midi % 12;
    final noteName = NoteName.values[noteIndex];
    final semitoneDiff = midi - baseMidi; // 與 C4 的半音差

    return PitchName(frequency, semitoneDiff.toDouble(), noteName: noteName, octave: octave);
  }

  PitchName copyWith({NoteName? noteName, int? octave, double? value, double? diff}) {
    return PitchName(
      value ?? this.value,
      diff ?? this.diff,
      noteName: noteName ?? this.noteName,
      octave: octave ?? this.octave,
    );
  }

  String getDisplayName() {
    return '${noteName.displayName}${octave >= 0 ? octave : ''}';
  }

  PitchName getNext([int delta = 1]) {
    final totalSemitones = (octave + 1) * 12 + noteName.index + delta;
    final newOctave = (totalSemitones ~/ 12) - 1;
    final newNoteIndex = totalSemitones % 12;
    final newNoteName = NoteName.values[newNoteIndex];
    return PitchName.fromNoteOctave(newNoteName, newOctave);
  }

  PitchName getPrevious([int delta = 1]) {
    return getNext(-delta);
  }

  @override
  String toString() {
    return 'PitchName(note: ${noteName.displayName}, octave: $octave, value: $value, diff: $diff)';
  }

  @override
  int compareTo(PitchName other) {
    return value.compareTo(other.value);
  }

  bool operator <(PitchName other) => compareTo(other) < 0;

  bool operator >(PitchName other) => compareTo(other) > 0;

  bool operator <=(PitchName other) => compareTo(other) <= 0;

  bool operator >=(PitchName other) => compareTo(other) >= 0;

  int diffPitchNamesCount(PitchName other) {
    return (octave - other.octave) * 12 + (noteName.index - other.noteName.index);
  }
}
