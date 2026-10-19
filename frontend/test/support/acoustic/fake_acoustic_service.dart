import 'dart:typed_data';

import 'package:frontend/models/acoustic/acoustic_result.dart';
import 'package:frontend/models/acoustic/hive_option.dart';
import 'package:frontend/services/acoustic/acoustic_service.dart';

/// Fake [AcousticService]. Analysis throws for the first [failures] calls,
/// then returns a result. Saved results are recorded for assertions.
class FakeAcousticService implements AcousticService {
  FakeAcousticService({
    this.failures = 1,
    this.historyFailures = 0,
    List<AcousticResult> history = const [],
    List<HiveOption>? hives,
    this.isDemo = false,
  }) : _seeded = List.of(history),
       hives = hives ?? [defaultHive];

  /// The hive used when none is given.
  static const HiveOption defaultHive = HiveOption(
    id: 'H-001',
    name: 'Hive H-001',
    apiary: 'Test apiary',
  );

  final int failures;

  /// Hives returned by [getHives].
  final List<HiveOption> hives;

  @override
  final bool isDemo;

  /// How many [getHistory] calls fail before one succeeds.
  int historyFailures;

  /// How many times [getHistory] has been called.
  int historyCalls = 0;

  final List<AcousticResult> _seeded;

  /// How many times [analyzeAudio] has been called.
  int analyzeCalls = 0;

  /// Filename and size of the last upload, for assertions.
  String? lastFilename;
  int? lastByteCount;

  /// Results passed to [saveResult], with their waveforms.
  final List<AcousticResult> saved = [];
  final List<List<double>> savedWaveforms = [];

  @override
  Future<AcousticResult> analyzeAudio({
    required String hiveId,
    required Uint8List bytes,
    required String filename,
  }) async {
    analyzeCalls++;
    lastFilename = filename;
    lastByteCount = bytes.length;
    if (analyzeCalls <= failures) {
      throw const AcousticException('Simulated server error');
    }
    return testResult(id: 'test-$analyzeCalls', hiveId: hiveId);
  }

  @override
  Future<void> saveResult(
    AcousticResult result, {
    List<double> waveform = const [],
  }) async {
    saved.add(result);
    savedWaveforms.add(waveform);
  }

  @override
  Future<List<AcousticResult>> getHistory({String? hiveId}) async {
    historyCalls++;
    if (historyFailures > 0) {
      historyFailures--;
      throw const AcousticException('Simulated history failure');
    }
    return [
      for (final r in [..._seeded, ...saved])
        if (hiveId == null || r.hiveId == hiveId) r,
    ];
  }

  @override
  Future<List<HiveOption>> getHives() async => hives;

  @override
  Future<List<double>?> getWaveform(String resultId) async => null;
}

/// A result for tests. Defaults to a confident "normal" reading.
AcousticResult testResult({
  String id = 'test-result',
  String hiveId = 'H-001',
  AcousticLabel label = AcousticLabel.normal,
  double confidence = 0.9,
  AudioQuality audioQuality = AudioQuality.good,
}) {
  return AcousticResult(
    id: id,
    hiveId: hiveId,
    label: label,
    confidence: confidence,
    recordedAt: DateTime(2026, 10, 16, 9, 20),
    audioQuality: audioQuality,
    modelVersion: 'test',
  );
}
