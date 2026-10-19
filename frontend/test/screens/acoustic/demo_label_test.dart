import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/acoustic/acoustic_strings.dart';
import 'package:frontend/screens/acoustic/hive_sound_monitor_screen.dart';
import 'package:frontend/screens/acoustic/result_screen.dart';
import 'package:frontend/services/acoustic/mock_acoustic_service.dart';

import '../../support/acoustic/fake_acoustic_service.dart';

void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('the mock reports itself as a demo, the real service must not', () {
    expect(MockAcousticService().isDemo, isTrue);
    expect(FakeAcousticService().isDemo, isFalse);
  });

  group('demo notice on the Result screen', () {
    testWidgets('shown when the service is a demo', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ResultScreen(
            service: FakeAcousticService(isDemo: true),
            result: testResult(),
          ),
        ),
      );

      expect(find.text(AcousticStrings.demoNotice), findsOneWidget);
    });

    testWidgets('hidden when the service is not a demo', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ResultScreen(
            service: FakeAcousticService(),
            result: testResult(),
          ),
        ),
      );

      expect(find.text(AcousticStrings.demoNotice), findsNothing);
    });
  });

  group('demo notice on the Monitor', () {
    testWidgets('shown with the mock service', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: HiveSoundMonitorScreen(
            service: MockAcousticService(delay: Duration.zero),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AcousticStrings.demoNotice), findsOneWidget);
    });

    testWidgets('hidden with a non-demo service', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: HiveSoundMonitorScreen(service: FakeAcousticService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AcousticStrings.demoNotice), findsNothing);
    });
  });
}
