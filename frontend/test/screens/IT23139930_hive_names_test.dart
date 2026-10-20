import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/IT23139930_hive_names.dart';
import 'package:frontend/models/IT23139930_hive_option.dart';
import 'package:frontend/screens/IT23139930_hive_sound_monitor_screen.dart';
import 'package:frontend/screens/IT23139930_recording_screen.dart';
import 'package:frontend/screens/IT23139930_result_screen.dart';
import 'package:frontend/screens/IT23139930_sound_history_screen.dart';
import 'package:frontend/services/IT23139930_recording_controller.dart';

import '../support/IT23139930_fake_acoustic_service.dart';
import '../support/IT23139930_fake_audio_recorder.dart';

/// A hive with a UUID id, as the real app will have.
const HiveOption boxOne = HiveOption(
  id: '3f2a9c10-uuid',
  name: 'Hive Box #01',
  apiary: 'Kandy Apiary',
);

void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    HiveNames.clear();
    HiveNames.remember([boxOne]);
  });

  tearDown(HiveNames.clear);

  group('HiveNames', () {
    test('returns the registered name for an id', () {
      expect(HiveNames.of(boxOne.id), 'Hive Box #01');
    });

    test('an unknown id shows as "Hive" followed by the id', () {
      expect(HiveNames.of('H-009'), 'Hive H-009');
    });

    test('a later registration replaces the name', () {
      HiveNames.remember([
        const HiveOption(
          id: '3f2a9c10-uuid',
          name: 'Hive Box #02',
          apiary: 'Kandy Apiary',
        ),
      ]);
      expect(HiveNames.of(boxOne.id), 'Hive Box #02');
    });
  });

  group('the hive name is shown on every screen', () {
    testWidgets('Recording', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: RecordingScreen(
            service: FakeAcousticService(),
            hiveId: boxOne.id,
            controller: RecordingController(
              hiveId: boxOne.id,
              recorder: FakeAudioRecorder(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Hive Box #01'), findsOneWidget);
      expect(find.textContaining(boxOne.id), findsNothing);
    });

    testWidgets('Result', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ResultScreen(
            service: FakeAcousticService(),
            result: testResult(hiveId: boxOne.id),
          ),
        ),
      );

      expect(find.textContaining('Hive Box #01 · '), findsOneWidget);
      expect(find.textContaining(boxOne.id), findsNothing);
    });

    testWidgets('Sound History header', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: SoundHistoryScreen(
            // One saved result, so the list (and its header) is shown.
            service: FakeAcousticService(
              hives: const [boxOne],
              history: [testResult(hiveId: boxOne.id)],
            ),
            hiveId: boxOne.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hive Box #01'), findsOneWidget);
      expect(find.textContaining(boxOne.id), findsNothing);
    });

    testWidgets('Monitor selector card and hive picker', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: HiveSoundMonitorScreen(
            service: FakeAcousticService(hives: const [boxOne]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hive Box #01'), findsOneWidget);
      expect(find.textContaining(boxOne.id), findsNothing);

      // Opening the picker lists the hive by name too.
      await tester.tap(find.text('Hive Box #01'));
      await tester.pumpAndSettle();
      expect(find.text('Hive Box #01'), findsNWidgets(2));
      expect(find.textContaining(boxOne.id), findsNothing);
    });
  });
}
