import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/recording_capture.dart';
import '../services/acoustic_service.dart';
import '../services/audio_upload.dart';
import 'analyze_audio_screen.dart';
import 'recording_screen.dart';

/// Navigation for the Record and Upload flows. Every screen in a flow gets
/// the same "Record Again" action, which pops back to the Monitor and starts
/// a new recording.
///
/// The Monitor awaits these futures and reloads when they finish, so a saved
/// result appears in Recent analyses.
class AcousticFlows {
  AcousticFlows._();

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
    navigator.popUntil((route) => route.isFirst);
    startRecording(navigator: navigator, service: service, hiveId: hiveId);
  }
}
