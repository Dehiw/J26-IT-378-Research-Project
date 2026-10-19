import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/acoustic/acoustic_entry.dart';
import 'package:frontend/models/acoustic/hive_names.dart';
import 'package:frontend/models/acoustic/hive_option.dart';
import 'package:frontend/screens/acoustic/hive_sound_monitor_screen.dart';
import 'package:frontend/services/acoustic/acoustic_service.dart';
import 'package:frontend/services/acoustic/mock_acoustic_service.dart';
import 'package:frontend/widgets/main_bottom_nav.dart';

import '../../support/acoustic/fake_acoustic_service.dart';

const List<HiveOption> twoHives = [
  HiveOption(id: 'H-001', name: 'Hive H-001', apiary: 'Yakkala Apiary'),
  HiveOption(id: 'H-002', name: 'Hive H-002', apiary: 'Kandy Apiary'),
];

void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(HiveNames.clear);
  tearDown(HiveNames.clear);
  navBarTests();

  group('initialHiveId', () {
    testWidgets('selects the given hive', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: HiveSoundMonitorScreen(
            service: FakeAcousticService(hives: twoHives),
            initialHiveId: 'H-002',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hive H-002'), findsOneWidget);
      expect(find.text('Hive H-001'), findsNothing);
    });

    testWidgets('an unknown id falls back to the first hive', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: HiveSoundMonitorScreen(
            service: FakeAcousticService(hives: twoHives),
            initialHiveId: 'H-999',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hive H-001'), findsOneWidget);
    });

    testWidgets('no id selects the first hive', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: HiveSoundMonitorScreen(
            service: FakeAcousticService(hives: twoHives),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hive H-001'), findsOneWidget);
    });
  });

  group('openSoundMonitor', () {
    late AcousticService original;

    setUp(() {
      original = acousticService;
    });

    tearDown(() {
      acousticService = original;
    });

    testWidgets('the app service is the mock, a demo, by default', (
      tester,
    ) async {
      expect(original, isA<MockAcousticService>());
      expect(original.isDemo, isTrue);
    });

    testWidgets('opens the Monitor for the given hive', (tester) async {
      phoneSize(tester);
      acousticService = FakeAcousticService(hives: twoHives);
      await tester.pumpWidget(_Launcher(hiveId: 'H-002'));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(HiveSoundMonitorScreen), findsOneWidget);
      expect(find.text('Hive H-002'), findsOneWidget);
    });

    testWidgets('without a hive id, opens on the first hive', (tester) async {
      phoneSize(tester);
      acousticService = FakeAcousticService(hives: twoHives);
      await tester.pumpWidget(_Launcher());

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Hive H-001'), findsOneWidget);
    });

    testWidgets('the Monitor opened from the app shows the demo notice with '
        'the mock', (tester) async {
      phoneSize(tester);
      acousticService = MockAcousticService(delay: Duration.zero);
      await tester.pumpWidget(_Launcher());

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Demo analysis, not a real AI result'), findsOneWidget);
    });
  });
}

/// A page with one button that calls [openSoundMonitor], like the Acoustic
/// tab does on the home screen.
class _Launcher extends StatelessWidget {
  const _Launcher({this.hiveId});

  final String? hiveId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => openSoundMonitor(context, hiveId: hiveId),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }
}

void navBarTests() {
  testWidgets('openSoundMonitor shows the shared nav bar on Acoustic', (
    tester,
  ) async {
    phoneSize(tester);
    final original = acousticService;
    acousticService = FakeAcousticService(hives: twoHives);
    addTearDown(() => acousticService = original);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => openSoundMonitor(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final bar = tester.widget<MainBottomNav>(find.byType(MainBottomNav));
    expect(bar.currentIndex, 3);

    // Tapping Acoustic again stays on the Monitor.
    await tester.tap(find.text('Acoustic'));
    await tester.pumpAndSettle();
    expect(find.byType(HiveSoundMonitorScreen), findsOneWidget);
  });
}
