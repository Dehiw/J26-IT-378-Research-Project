import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/recording_capture.dart';

/// Debug-only helper for the dev entry. Writes the last recording to the
/// system temp folder so its format can be checked in an audio player.
/// This is the only acoustic file that uses dart:io, and it lives in dev/.
class WavDebugSaver {
  WavDebugSaver._();

  /// Saves [capture] and returns the full path, or null outside debug builds.
  static Future<String?> save(RecordingCapture capture) async {
    if (!kDebugMode) return null;

    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'hive_sense_debug_${capture.filename}';
    final file = File(path);
    await file.writeAsBytes(capture.wavBytes, flush: true);

    debugPrint(
      'Debug WAV saved: $path '
      '(${capture.sampleRate} Hz, ${capture.channels} ch, 16-bit PCM, '
      '${capture.duration.inMilliseconds} ms)',
    );
    return path;
  }
}
