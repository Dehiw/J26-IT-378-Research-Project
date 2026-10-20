import 'dart:typed_data';

/// One finished recording, before analysis. Kept apart from [AcousticResult]:
/// the audio bytes and waveform belong to the recording, not to the result.
class RecordingCapture {
  /// Complete WAV file (header plus 16-bit PCM).
  final Uint8List wavBytes;

  /// Name sent with the upload, such as "hive_H-001_20261015_093012.wav".
  final String filename;

  /// Normalised 0-1 level samples from the live amplitude stream, one per
  /// tick, for the waveform preview.
  final List<double> waveform;

  final Duration duration;

  /// Format written in the WAV header (the format the device actually used).
  final int sampleRate;
  final int channels;

  const RecordingCapture({
    required this.wavBytes,
    required this.filename,
    required this.waveform,
    required this.duration,
    required this.sampleRate,
    required this.channels,
  });
}
