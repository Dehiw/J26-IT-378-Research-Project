import 'dart:typed_data';

import 'dart:math' as math;

import '../models/acoustic_result.dart';
import '../models/hive_option.dart';
import 'acoustic_service.dart';

/// In-memory stand-in for the real acoustic backend. Returns realistic fake
/// results and cycles through all five states so every UI path can be seen.
class MockAcousticService implements AcousticService {
  MockAcousticService({
    this.delay = const Duration(milliseconds: 1500),
    List<AcousticResult>? seed,
    DateTime? now,
  })  : _history = seed ?? _seedHistory(now ?? DateTime.now()),
        _waveforms = {} {
    _waveforms.addAll(_seedWaveforms(_history));
  }

  /// Simulated network and processing time for each call.
  final Duration delay;

  static const String mockModelVersion = 'mock-0.1';

  static const List<AcousticLabel> _cycle = AcousticLabel.values;

  static const List<HiveOption> _hives = [
    HiveOption(id: 'H-001', apiary: 'Yakkala Apiary'),
    HiveOption(id: 'H-002', apiary: 'Kandy Apiary'),
  ];

  final List<AcousticResult> _history;
  final Map<String, List<double>> _waveforms;
  int _nextLabelIndex = 0;

  @override
  Future<List<HiveOption>> getHives() async {
    await Future<void>.delayed(delay ~/ 3);
    return _hives;
  }

  @override
  Future<List<double>?> getWaveform(String resultId) async {
    await Future<void>.delayed(delay ~/ 3);
    return _waveforms[resultId];
  }

  @override
  Future<AcousticResult> analyzeAudio({
    required String hiveId,
    required Uint8List bytes,
    required String filename,
  }) async {
    if (bytes.isEmpty) {
      throw const AcousticException('The recording is empty.');
    }
    await Future<void>.delayed(delay);

    final label = _cycle[_nextLabelIndex % _cycle.length];
    _nextLabelIndex++;
    final now = DateTime.now();
    final result = AcousticResult(
      id: 'mock-${now.microsecondsSinceEpoch}',
      hiveId: hiveId,
      label: label,
      confidence: _confidenceFor(label),
      recordedAt: now,
      audioQuality: label == AcousticLabel.unclearRecording
          ? AudioQuality.poor
          : AudioQuality.good,
      modelVersion: mockModelVersion,
    );
    _history.insert(0, result);
    _waveforms[result.id] = _syntheticWaveform(bytes.length);
    return result;
  }

  @override
  Future<List<AcousticResult>> getHistory() async {
    await Future<void>.delayed(delay ~/ 3);
    return List.unmodifiable(_history);
  }

  static double _confidenceFor(AcousticLabel label) => switch (label) {
        AcousticLabel.normal => 0.89,
        AcousticLabel.queenless => 0.87,
        AcousticLabel.swarming => 0.79,
        AcousticLabel.stressAbnormal => 0.72,
        AcousticLabel.unclearRecording => 0.41,
      };

  /// Synthetic 0-1 samples, deterministic for a given seed.
  static List<double> _syntheticWaveform(int seed, {int count = 40}) {
    final random = math.Random(seed);
    return [for (var i = 0; i < count; i++) 0.2 + random.nextDouble() * 0.8];
  }

  /// Waveforms exist for some seeded results only, so the UI's
  /// "no preview" path gets exercised too.
  static Map<String, List<double>> _seedWaveforms(
    List<AcousticResult> results,
  ) {
    const withPreview = {'seed-0', 'seed-1', 'seed-3', 'seed-6'};
    return {
      for (final r in results)
        if (withPreview.contains(r.id)) r.id: _syntheticWaveform(r.id.hashCode),
    };
  }

  /// Eight recordings over the last six days, across two hives, covering
  /// all five states.
  static List<AcousticResult> _seedHistory(DateTime now) {
    // (label, confidence, hiveId, how long ago, audio quality)
    final entries = <(AcousticLabel, double, String, Duration, AudioQuality)>[
      (AcousticLabel.normal, 0.89, 'H-001', const Duration(hours: 2),
          AudioQuality.good),
      (AcousticLabel.swarming, 0.79, 'H-001', const Duration(hours: 28),
          AudioQuality.good),
      (AcousticLabel.normal, 0.84, 'H-002', const Duration(days: 1, hours: 6),
          AudioQuality.good),
      (AcousticLabel.queenless, 0.87, 'H-001', const Duration(days: 2, hours: 3),
          AudioQuality.good),
      (AcousticLabel.stressAbnormal, 0.72, 'H-002', const Duration(days: 3),
          AudioQuality.fair),
      (AcousticLabel.unclearRecording, 0.41, 'H-002', const Duration(days: 4),
          AudioQuality.poor),
      (AcousticLabel.normal, 0.91, 'H-001', const Duration(days: 5),
          AudioQuality.good),
      (AcousticLabel.swarming, 0.81, 'H-002', const Duration(days: 6),
          AudioQuality.good),
    ];

    final results = [
      for (var i = 0; i < entries.length; i++)
        AcousticResult(
          id: 'seed-$i',
          hiveId: entries[i].$3,
          label: entries[i].$1,
          confidence: entries[i].$2,
          recordedAt: now.subtract(entries[i].$4),
          audioQuality: entries[i].$5,
          modelVersion: mockModelVersion,
        ),
    ];
    results.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return results;
  }
}
