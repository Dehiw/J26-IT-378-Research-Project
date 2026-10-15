/// Tunable settings for the Bee Acoustic Analysis module.
///
/// Temporary values: the confidence threshold will be tuned after model
/// validation.
class AcousticConfig {
  AcousticConfig._();

  /// Results below this confidence (0-1) are shown as "Unclear Recording".
  static const double confidenceThreshold = 0.60;

  /// Longest recording the Recording screen will accept.
  static const Duration maxRecordingDuration = Duration(seconds: 30);
}
