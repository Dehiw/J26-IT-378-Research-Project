import 'dart:math' as math;
import 'dart:typed_data';

/// 16-bit little-endian PCM test signals.
///
/// [sine] is a 440 Hz tone at [amplitude] (0-1 of full scale). The bytes
/// cover [seconds] of audio at [sampleRate] and [channels].
Uint8List sine({
  required double seconds,
  required int sampleRate,
  int channels = 1,
  double amplitude = 0.2,
}) {
  final frames = (seconds * sampleRate).round();
  final bytes = Uint8List(frames * channels * 2);
  final view = ByteData.sublistView(bytes);
  for (var frame = 0; frame < frames; frame++) {
    final value = amplitude * math.sin(2 * math.pi * 440 * frame / sampleRate);
    final sample = (value * 32767).round();
    for (var ch = 0; ch < channels; ch++) {
      final offset = (frame * channels + ch) * 2;
      view.setInt16(offset, sample, Endian.little);
    }
  }
  return bytes;
}

/// Digital silence of the same length as [sine].
Uint8List silence({
  required double seconds,
  required int sampleRate,
  int channels = 1,
}) => Uint8List((seconds * sampleRate).round() * channels * 2);

/// Constant full-scale samples, as produced by a clipping input.
Uint8List fullScale({
  required double seconds,
  required int sampleRate,
  int channels = 1,
}) {
  final bytes = Uint8List((seconds * sampleRate).round() * channels * 2);
  final view = ByteData.sublistView(bytes);
  for (var i = 0; i < bytes.length ~/ 2; i++) {
    view.setInt16(i * 2, 32767, Endian.little);
  }
  return bytes;
}
