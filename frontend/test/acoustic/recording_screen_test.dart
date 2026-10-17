import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/acoustic/acoustic_strings.dart';
import 'package:frontend/acoustic/models/acoustic_result.dart';
import 'package:frontend/acoustic/screens/recording_screen.dart';
import 'package:frontend/acoustic/services/recording_controller.dart';

import 'support/fake_audio_recorder.dart';
import 'support/pcm_signal.dart';
import 'support/fake_acoustic_service.dart';

/// Lets queued futures and stream events run. Animations are not settled
/// because the analysing spinner never stops on its own.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets(
    'analysis failure shows an error, and Retry sends the recording again',
    (tester) async {
      final recorder = FakeAudioRecorder();
      final controller = RecordingController(
        hiveId: 'H-001',
        recorder: recorder,
      );
      final service = FakeAcousticService(failures: 1);

      // Phone-sized viewport, so the bottom buttons are on screen.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: RecordingScreen(
            service: service,
            hiveId: 'H-001',
            controller: controller,
          ),
        ),
      );

      // Record four seconds of 16 kHz mono 16-bit audio, then stop.
      await tester.tap(find.text(AcousticStrings.startRecording));
      await pumpFrames(tester);
      recorder.emitAudio(sine(seconds: 4, sampleRate: 16000));
      await pumpFrames(tester);
      await tester.tap(find.text(AcousticStrings.stopRecording));
      await pumpFrames(tester);

      // First analysis throws: the error and Retry are shown.
      expect(service.analyzeCalls, 1);
      expect(find.text(AcousticStrings.analysisFailed), findsOneWidget);
      expect(find.text(AcousticStrings.retry), findsOneWidget);
      expect(find.text(AcousticStrings.analyzingHiveSound), findsNothing);

      // Retry sends the same recording again, and this time it succeeds.
      await tester.tap(find.text(AcousticStrings.retry));
      await pumpFrames(tester);
      await tester.pumpAndSettle();

      expect(service.analyzeCalls, 2);
      expect(service.lastFilename, endsWith('.wav'));
      expect(service.lastByteCount, 44 + 16000 * 2 * 4);
      expect(
        find.text(AcousticStrings.labelTitle(AcousticLabel.normal)),
        findsOneWidget,
      );
      expect(find.text(AcousticStrings.saveResult), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
