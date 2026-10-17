import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/acoustic/acoustic_config.dart';
import 'package:frontend/acoustic/services/signal_stats.dart';

import 'support/pcm_signal.dart';

SignalQuality rate(Uint8List pcm) {
  final stats = SignalStats.fromPcm16(pcm);
  return SignalQualityRules.classify(
    hasAudio: pcm.isNotEmpty,
    rmsDb: stats.rmsDb,
    clippedRatio: stats.clippedRatio,
  );
}

/// Sets [count] samples of [pcm] to full scale, starting at sample 100.
void clipSamples(Uint8List pcm, int count) {
  final view = ByteData.sublistView(pcm);
  for (var i = 0; i < count; i++) {
    view.setInt16((100 + i) * 2, 32767, Endian.little);
  }
}

void main() {
  group('SignalQualityRules', () {
    test('silence is Poor', () {
      final pcm = silence(seconds: 1, sampleRate: 16000);
      expect(SignalStats.fromPcm16(pcm).isSilent, isTrue);
      expect(rate(pcm), SignalQuality.poor);
    });

    test('no data at all is Poor', () {
      expect(
        SignalQualityRules.classify(
          hasAudio: false,
          rmsDb: -20,
          clippedRatio: 0,
        ),
        SignalQuality.poor,
      );
    });

    test('very quiet audio is Fair', () {
      // Peak about -47 dBFS and RMS about -54 dBFS: above the silence floor,
      // below the quiet threshold.
      final pcm = sine(seconds: 1, sampleRate: 16000, amplitude: 0.0045);
      final stats = SignalStats.fromPcm16(pcm);
      expect(stats.rmsDb, greaterThan(AcousticConfig.silenceFloorDb));
      expect(stats.rmsDb, lessThan(AcousticConfig.quietRmsDb));
      expect(rate(pcm), SignalQuality.fair);
    });

    test('normal level is Good', () {
      final pcm = sine(seconds: 1, sampleRate: 16000, amplitude: 0.2);
      expect(rate(pcm), SignalQuality.good);
    });

    test('a single clipped sample does not make the recording Poor', () {
      final pcm = sine(seconds: 4, sampleRate: 16000, amplitude: 0.2);
      clipSamples(pcm, 1);
      expect(SignalStats.fromPcm16(pcm).clippedSamples, 1);
      expect(rate(pcm), SignalQuality.good);
    });

    test('a short tap of clipping under the ratio is not Poor', () {
      // 10 clipped samples in 4 s at 16 kHz is about 0.016%, under 0.1%.
      final pcm = sine(seconds: 4, sampleRate: 16000, amplitude: 0.2);
      clipSamples(pcm, 10);
      expect(rate(pcm), SignalQuality.good);
    });

    test('sustained clipping is Poor', () {
      final pcm = fullScale(seconds: 1, sampleRate: 16000);
      expect(SignalStats.fromPcm16(pcm).clippedRatio, 1);
      expect(rate(pcm), SignalQuality.poor);
    });

    test('clipping above the ratio is Poor', () {
      // 100 clipped samples in 1 s at 16 kHz is about 0.6%, over 0.1%.
      final pcm = sine(seconds: 1, sampleRate: 16000, amplitude: 0.2);
      clipSamples(pcm, 100);
      expect(rate(pcm), SignalQuality.poor);
    });
  });

  group('SignalStats', () {
    test('an empty buffer reports silence, not a level', () {
      final stats = SignalStats();
      expect(stats.samples, 0);
      expect(stats.rmsDb, SignalStats.silentDb);
      expect(stats.peakDb, SignalStats.silentDb);
      expect(stats.clippedRatio, 0);
      expect(stats.isSilent, isTrue);
    });

    test('full-scale sine has about -3 dBFS RMS', () {
      final stats = SignalStats.fromPcm16(
        sine(seconds: 1, sampleRate: 16000, amplitude: 1.0),
      );
      expect(stats.rmsDb, closeTo(-3.0, 0.2));
    });

    test('an odd trailing byte is ignored', () {
      final even = sine(seconds: 0.5, sampleRate: 16000);
      final odd = Uint8List.fromList([...even, 0x7f]);
      expect(SignalStats.fromPcm16(odd).samples, even.length ~/ 2);
    });
  });
}
