import '../acoustic_config.dart';

/// Sound state predicted for one recording.
enum AcousticLabel {
  normal,
  queenless,
  swarming,
  stressAbnormal,
  unclearRecording,
}

/// Quality of the captured audio, as reported by the analysis.
enum AudioQuality { good, fair, poor }

/// One analysed hive recording.
class AcousticResult {
  final String id;
  final String hiveId;
  final AcousticLabel label;

  /// Model confidence, 0-1.
  final double confidence;
  final DateTime recordedAt;
  final AudioQuality audioQuality;
  final String modelVersion;

  const AcousticResult({
    required this.id,
    required this.hiveId,
    required this.label,
    required this.confidence,
    required this.recordedAt,
    required this.audioQuality,
    required this.modelVersion,
  });

  /// The state to show the user. Poor audio or confidence below
  /// [AcousticConfig.confidenceThreshold] always shows as unclear.
  AcousticLabel get displayLabel {
    if (audioQuality == AudioQuality.poor ||
        confidence < AcousticConfig.confidenceThreshold) {
      return AcousticLabel.unclearRecording;
    }
    return label;
  }
}
