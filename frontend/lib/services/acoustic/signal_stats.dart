import 'dart:math' as math;
import 'dart:typed_data';

import 'package:frontend/utils/acoustic/acoustic_config.dart';

/// Live signal quality shown next to the mic button.
enum SignalQuality { good, fair, poor }

/// Level statistics for 16-bit little-endian PCM. Levels are in dBFS, where
/// 0 dBFS is full scale. Silence is reported as -160 dBFS.
class SignalStats {
  static const double silentDb = -160;

  SignalStats();

  int samples = 0;

  /// Samples at or above [AcousticConfig.clippingPeakDb].
  int clippedSamples = 0;

  double _sumSquares = 0;
  double _peak = 0;

  /// Adds the samples in [pcm16]. An odd trailing byte is ignored.
  void addPcm16(Uint8List pcm16) {
    final view = ByteData.sublistView(pcm16);
    final count = pcm16.length ~/ 2;
    final clipLevel = _clipLevel;
    for (var i = 0; i < count; i++) {
      final sample = view.getInt16(i * 2, Endian.little).toDouble();
      final normalised = sample.abs() / 32768;
      _sumSquares += normalised * normalised;
      if (normalised > _peak) _peak = normalised;
      if (normalised >= clipLevel) clippedSamples++;
    }
    samples += count;
  }

  /// Statistics for [pcm16] on its own.
  factory SignalStats.fromPcm16(Uint8List pcm16) {
    final stats = SignalStats();
    stats.addPcm16(pcm16);
    return stats;
  }

  /// Root-mean-square level in dBFS.
  double get rmsDb {
    if (samples == 0 || _sumSquares == 0) return silentDb;
    return _toDb(math.sqrt(_sumSquares / samples));
  }

  /// Largest sample magnitude in dBFS.
  double get peakDb => _peak == 0 ? silentDb : _toDb(_peak);

  /// Share of samples at or above the clipping level, 0-1.
  double get clippedRatio => samples == 0 ? 0 : clippedSamples / samples;

  /// True when the level is below the silence floor, including no samples.
  bool get isSilent => rmsDb < AcousticConfig.silenceFloorDb;

  /// Clipping level as a linear fraction of full scale.
  static double get _clipLevel =>
      math.pow(10, AcousticConfig.clippingPeakDb / 20).toDouble();

  static double _toDb(double linear) =>
      math.max(silentDb, 20 * math.log(linear) / math.ln10);
}

/// Quality rules, kept pure so they can be tested without a microphone.
class SignalQualityRules {
  SignalQualityRules._();

  /// Poor when there is no audio, the level is silent, or clipping is
  /// sustained (more than [AcousticConfig.maxClippedSampleRatio] of samples).
  /// Fair when the level is very quiet. Good otherwise.
  static SignalQuality classify({
    required bool hasAudio,
    required double rmsDb,
    required double clippedRatio,
  }) {
    if (!hasAudio || rmsDb < AcousticConfig.silenceFloorDb) {
      return SignalQuality.poor;
    }
    if (clippedRatio > AcousticConfig.maxClippedSampleRatio) {
      return SignalQuality.poor;
    }
    if (rmsDb < AcousticConfig.quietRmsDb) return SignalQuality.fair;
    return SignalQuality.good;
  }
}
