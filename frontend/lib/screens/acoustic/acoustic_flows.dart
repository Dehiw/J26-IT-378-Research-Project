import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:frontend/models/acoustic/recording_capture.dart';
import 'package:frontend/services/acoustic/acoustic_service.dart';
import 'package:frontend/services/acoustic/audio_upload.dart';
import 'package:frontend/screens/acoustic/analyze_audio_screen.dart';
import 'package:frontend/screens/acoustic/recording_screen.dart';

/// Navigation for the Record and Upload flows. Every screen in a flow gets
/// the same "Record Again" action, which pops back to the Monitor and starts
/// a new recording.
///
/// The Monitor awaits these futures and reloads when they finish, so a saved
/// result appears in Recent analyses.
class AcousticFlows {
  AcousticFlows._();

  /// Route name of the Monitor. "Record Again" pops back to it, so it works
  /// both in the demo (where the Monitor is the first route) and in the app
  /// (where it is pushed on top of Home).
  static const String monitorRouteName = '/acoustic/monitor';

  /// Bumped after a result is saved. The Monitor listens and reloads, so the
  /// saved result shows in Recent analyses even though the flow's own future
  /// completes earlier (the screens replace each other).
  static final ValueNotifier<int> resultSaved = ValueNotifier<int>(0);

  /// Pops back to the Monitor, or to the first route when the Monitor is not
  /// in the stack (the dev demo entry).
  static void backToMonitor(NavigatorState navigator) {
    navigator.popUntil(
      (route) => route.settings.name == monitorRouteName || route.isFirst,
    );
  }

  /// Opens the Recording screen for [hiveId].
  static Future<void> startRecording({
    required NavigatorState navigator,
    required AcousticService service,
    required String hiveId,
    ValueChanged<RecordingCapture>? onCaptured,
  }) {
    return navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => RecordingScreen(
          service: service,
          hiveId: hiveId,
          onCaptured: onCaptured,
          onRecordAgain: () => _recordAgain(
            navigator: navigator,
            service: service,
            hiveId: hiveId,
          ),
        ),
      ),
    );
  }

  /// Analyses an uploaded file for [hiveId]. The file has already been
  /// picked and validated by the Monitor.
  static Future<void> analyzeUpload({
    required NavigatorState navigator,
    required AcousticService service,
    required String hiveId,
    required PickedAudio audio,
  }) {
    return navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AnalyzeAudioScreen(
          service: service,
          hiveId: hiveId,
          bytes: Uint8List.fromList(audio.bytes),
          filename: audio.filename,
          onRecordAgain: () => _recordAgain(
            navigator: navigator,
            service: service,
            hiveId: hiveId,
          ),
        ),
      ),
    );
  }

  static void _recordAgain({
    required NavigatorState navigator,
    required AcousticService service,
    required String hiveId,
  }) {
    backToMonitor(navigator);
    startRecording(navigator: navigator, service: service, hiveId: hiveId);
  }
}
