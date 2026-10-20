import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/IT23139930_acoustic_strings.dart';
import 'package:frontend/screens/IT23139930_recording_screen.dart';
import 'package:frontend/services/IT23139930_microphone_permission.dart';
import 'package:frontend/services/IT23139930_recording_controller.dart';

import '../support/IT23139930_fake_acoustic_service.dart';
import '../support/IT23139930_fake_audio_recorder.dart';

void main() {
  testWidgets(
    'no audio shows the no-sound banner and Poor quality, and stopping says '
    'no audio was captured',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final recorder = FakeAudioRecorder();
      final controller = RecordingController(
        hiveId: 'H-001',
        recorder: recorder,
        // Zero means "no data yet" counts as missing at the first tick.
        noDataTimeout: Duration.zero,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RecordingScreen(
            service: FakeAcousticService(),
            hiveId: 'H-001',
            controller: controller,
          ),
        ),
      );

      await tester.tap(find.text(AcousticStrings.startRecording));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final banner = AcousticStrings.soundMissingText(
        android: MicrophonePermission.isAndroid,
      );
      expect(find.text(banner), findsOneWidget);
      expect(
        find.text(
          '${AcousticStrings.qualityLabel}: ${AcousticStrings.qualityPoor}',
        ),
        findsOneWidget,
      );

      final stop = find.text(AcousticStrings.stopRecording);
      await tester.ensureVisible(stop);
      await tester.tap(stop);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        find.textContaining(AcousticStrings.noAudioCaptured),
        findsOneWidget,
      );
      expect(find.text(AcousticStrings.recordingTooShort), findsNothing);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
