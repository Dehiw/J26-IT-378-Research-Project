import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Result of asking for microphone access.
enum MicrophoneAccess { granted, denied }

/// Microphone permission for the Recording screen, using [AudioRecorder]
/// only.
///
/// On Android, [AudioRecorder.hasPermission] shows the system prompt. Android
/// shows that prompt only a limited number of times. After that it returns
/// false without showing anything, so a denial is reported the same way
/// whether the user just refused or Android stopped asking. The screen then
/// gives text instructions for turning the permission on in Settings.
///
/// On Windows there is no in-app prompt: access is controlled by the OS
/// privacy setting, which the same call reports.
class MicrophonePermission {
  MicrophonePermission._();

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Checks access and asks for it when the platform allows a prompt.
  static Future<MicrophoneAccess> request(AudioRecorder recorder) async {
    final allowed = await recorder.hasPermission();
    return allowed ? MicrophoneAccess.granted : MicrophoneAccess.denied;
  }
}
