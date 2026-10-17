import 'dart:typed_data';

import '../acoustic_config.dart';
import '../acoustic_strings.dart';

/// A file the user picked for upload. Holds bytes, not a path, so the same
/// code works on every platform.
class PickedAudio {
  final String filename;
  final Uint8List bytes;

  const PickedAudio({required this.filename, required this.bytes});
}

/// Opens the system file picker. The app supplies the implementation, so the
/// screens do not depend on a plugin directly.
abstract class AudioFilePicker {
  /// Returns the chosen file, or null if the user cancelled.
  Future<PickedAudio?> pick();
}

/// Why an upload was rejected.
enum AudioUploadProblem { unsupportedType, empty, tooLarge }

/// Checks a picked file before it is analysed.
class AudioUploadValidator {
  AudioUploadValidator._();

  /// Returns the first problem with [audio], or null when it can be uploaded.
  static AudioUploadProblem? check(
    PickedAudio audio, {
    int maxBytes = AcousticConfig.maxUploadBytes,
  }) {
    if (!AcousticConfig.allowedUploadExtensions.contains(
      extensionOf(audio.filename),
    )) {
      return AudioUploadProblem.unsupportedType;
    }
    if (audio.bytes.isEmpty) return AudioUploadProblem.empty;
    if (audio.bytes.length > maxBytes) return AudioUploadProblem.tooLarge;
    return null;
  }

  /// Lower-case extension without the dot, or an empty string.
  static String extensionOf(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) return '';
    return filename.substring(dot + 1).toLowerCase();
  }

  /// User-facing message for [problem].
  static String message(
    AudioUploadProblem problem, {
    int maxBytes = AcousticConfig.maxUploadBytes,
  }) => switch (problem) {
    AudioUploadProblem.unsupportedType => AcousticStrings.uploadUnsupportedType,
    AudioUploadProblem.empty => AcousticStrings.uploadEmpty,
    AudioUploadProblem.tooLarge => AcousticStrings.uploadTooLarge(
      maxBytes ~/ (1024 * 1024),
    ),
  };
}
