import 'dart:typed_data';

import 'package:frontend/models/IT23139930_acoustic_result.dart';
import 'package:frontend/models/IT23139930_hive_option.dart';

/// Analysis failed (empty file, unsupported format, server error, ...).
class AcousticException implements Exception {
  final String message;
  const AcousticException(this.message);

  @override
  String toString() => 'AcousticException: $message';
}

/// Contract for hive sound analysis. The UI depends only on this interface.
/// [HttpAcousticService] calls the backend model; [MockAcousticService] makes
/// up results. Which one runs is set by `AcousticConfig.useRealModel`.
///
/// HTTP contract (all under the API base URL, JWT required):
///
///   POST /acoustic/analyze   multipart/form-data
///     fields: hive_id, source ("record" | "upload"), audio (WAV file)
///     200 JSON: { id, hive_id, label ("normal" | "queenless"), confidence
///       (0-1), audio_quality, model_version, analyzed_at, clip_count,
///       clip_probabilities, source, saved: false }
///     400 bad or too short audio, 503 model not available.
///   POST /acoustic/results/{id}/save   marks the result saved.
///   GET  /acoustic/history?hive_id=    { "results": [...] } saved only,
///                                      newest first.
///
/// The real model has two classes only. "swarming" and "stress_abnormal"
/// are never returned. There is no waveform endpoint: getWaveform is null.
///
/// Waveform samples are kept beside the result, not inside AcousticResult.
abstract class AcousticService {
  /// True when results are made up (the mock). The UI shows a "Demo
  /// analysis" notice while this is true, and the "Experimental AI model"
  /// notice when it is false.
  bool get isDemo;

  /// Analyses one recording for [hiveId]. [bytes] and [filename] are used
  /// instead of a File so the same call works on web and mobile.
  Future<AcousticResult> analyzeAudio({
    required String hiveId,
    required Uint8List bytes,
    required String filename,
  });

  /// Stores an analysis the user chose to keep. Unsaved analyses do not
  /// appear in [getHistory]. [waveform] is empty when there are no samples.
  Future<void> saveResult(
    AcousticResult result, {
    List<double> waveform = const [],
  });

  /// Saved analyses, newest first. Pass [hiveId] to limit the list to one
  /// hive; null returns every hive.
  Future<List<AcousticResult>> getHistory({String? hiveId});

  /// Hives the user can record for.
  Future<List<HiveOption>> getHives();

  /// Normalised 0-1 waveform samples for [resultId], or null when none exist.
  Future<List<double>?> getWaveform(String resultId);
}
