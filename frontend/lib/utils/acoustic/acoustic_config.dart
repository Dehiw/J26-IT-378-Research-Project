/// Tunable settings for the Bee Acoustic Analysis module.
///
/// Temporary values: the confidence threshold will be tuned after model
/// validation.
class AcousticConfig {
  AcousticConfig._();

  /// true: analyse through the backend (real model). false: use the mock.
  /// With true, a missing backend or model shows an error, never a fake result.
  static const bool useRealModel = true;

  /// Results below this confidence (0-1) are shown as "Unclear Recording".
  static const double confidenceThreshold = 0.60;

  /// Longest recording the Recording screen will accept.
  static const Duration maxRecordingDuration = Duration(seconds: 30);

  /// Shortest recording that is sent for analysis.
  static const Duration minRecordingDuration = Duration(seconds: 3);

  /// Sample rate of captured audio, in Hz. Provisional: change it to match
  /// the rate the model was trained on.
  static const int recordingSampleRate = 16000;

  /// Mono capture. Bee sound analysis does not need stereo.
  static const int recordingChannels = 1;

  /// Level (RMS, dBFS) below which the signal counts as silence. Provisional.
  static const double silenceFloorDb = -60;

  /// Level (RMS, dBFS) below which the signal is only fair: very quiet.
  /// Provisional, to be tuned on real hive recordings.
  static const double quietRmsDb = -45;

  /// Samples at or above this level (dBFS) count as clipped. Provisional.
  static const double clippingPeakDb = -1;

  /// The recording is Poor only when more than this share of samples are
  /// clipped. One clipped sample (for example, a tap on the hive) does not
  /// make the whole recording Poor. 0.1% is 16 samples per second at 16 kHz.
  static const double maxClippedSampleRatio = 0.001;

  /// Days shown in the Sound History abnormality trend, counting today.
  static const int trendWindowDays = 7;

  /// No audio data this long after starting means the microphone is not
  /// delivering sound (for example, blocked by the Windows privacy setting).
  static const Duration noDataTimeout = Duration(milliseconds: 1500);

  /// Continuous silence this long shows the "no sound" warning.
  static const Duration silenceTimeout = Duration(seconds: 2);

  /// Each waveform bar covers this much audio.
  static const Duration waveformBucket = Duration(milliseconds: 100);

  /// File types accepted by Upload Audio (lower case, no dot).
  static const List<String> allowedUploadExtensions = ['wav', 'mp3'];

  /// Largest upload accepted, in bytes (10 MiB). At 16 kHz mono 16-bit WAV
  /// (32000 bytes per second) this is about 5 minutes 27 seconds of audio.
  /// MP3 lasts longer at the same size, depending on its bitrate.
  static const int maxUploadBytes = 10 * 1024 * 1024;
}
