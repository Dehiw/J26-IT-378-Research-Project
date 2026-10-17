import 'dart:typed_data';

import 'package:frontend/acoustic/models/acoustic_result.dart';
import 'package:frontend/acoustic/models/hive_option.dart';
import 'package:frontend/acoustic/services/acoustic_service.dart';

/// Fake [AcousticService]. Analysis throws for the first [failures] calls,
/// then returns a result. Saved results are recorded for assertions.
class FakeAcousticService implements AcousticService {
  FakeAcousticService({this.failures = 1});

  final int failures;

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
  Future<List<AcousticResult>> getHistory() async => saved;

  @override
  Future<List<HiveOption>> getHives() async => const [
    HiveOption(id: 'H-001', apiary: 'Test apiary'),
  ];

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
