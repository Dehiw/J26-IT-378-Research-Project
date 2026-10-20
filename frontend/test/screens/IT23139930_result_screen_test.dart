import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/IT23139930_acoustic_strings.dart';
import 'package:frontend/models/IT23139930_acoustic_result.dart';
import 'package:frontend/screens/IT23139930_acoustic_flows.dart';
import 'package:frontend/screens/IT23139930_hive_sound_monitor_screen.dart';
import 'package:frontend/screens/IT23139930_result_screen.dart';
import 'package:frontend/widgets/IT23139930_confidence_indicator.dart';
import 'package:frontend/widgets/IT23139930_waveform_view.dart';

import '../support/IT23139930_fake_acoustic_service.dart';

/// Opens [ResultScreen] from a root page, so a successful save can be seen
/// returning to that page.
Future<void> pumpResult(
  WidgetTester tester, {
  required FakeAcousticService service,
  required AcousticResult result,
  List<double> waveform = const [],
  VoidCallback? onRecordAgain,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ResultScreen(
                    service: service,
                    result: result,
                    waveform: waveform,
                    onRecordAgain: onRecordAgain,
                  ),
                ),
              ),
              child: const Text('open result'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open result'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Save Result returns to the Monitor, which reloads', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = FakeAcousticService();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AcousticFlows.monitorRouteName),
        builder: (_) => HiveSoundMonitorScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();
    final callsBefore = service.historyCalls;

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(service: service, result: testResult()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AcousticStrings.saveResult));
    await tester.pumpAndSettle();

    expect(find.byType(HiveSoundMonitorScreen), findsOneWidget);
    expect(find.text('home'), findsNothing, reason: 'not sent to Home');
    expect(service.historyCalls, greaterThan(callsBefore));
  });

  testWidgets('Save Result stores the result and returns to the first page', (
    tester,
  ) async {
    final service = FakeAcousticService();
    final result = testResult(id: 'keep-me');
    final waveform = List<double>.filled(40, 0.5);

    await pumpResult(
      tester,
      service: service,
      result: result,
      waveform: waveform,
      onRecordAgain: () {},
    );
    await tester.tap(find.text(AcousticStrings.saveResult));
    await tester.pumpAndSettle();

    expect(service.saved.single.id, 'keep-me');
    expect(service.savedWaveforms.single, waveform);
    expect(find.text('open result'), findsOneWidget, reason: 'back on root');
  });

  testWidgets('a normal result shows Save, Record Again, the card and note', (
    tester,
  ) async {
    await pumpResult(
      tester,
      service: FakeAcousticService(),
      result: testResult(label: AcousticLabel.normal),
      onRecordAgain: () {},
    );

    expect(
      find.text(AcousticStrings.labelTitle(AcousticLabel.normal)),
      findsOneWidget,
    );
    expect(find.text(AcousticStrings.whatThisMeans), findsOneWidget);
    expect(find.text(AcousticStrings.guidanceNote), findsOneWidget);
    expect(find.byType(ConfidenceIndicator), findsOneWidget);
    expect(find.text(AcousticStrings.saveResult), findsOneWidget);
    expect(find.text(AcousticStrings.recordAgain), findsOneWidget);
  });

  testWidgets('an unclear recording shows tips and only Record Again', (
    tester,
  ) async {
    var recordAgainCalls = 0;
    await pumpResult(
      tester,
      service: FakeAcousticService(),
      result: testResult(
        label: AcousticLabel.normal,
        audioQuality: AudioQuality.poor,
      ),
      onRecordAgain: () => recordAgainCalls++,
    );

    expect(
      find.text(AcousticStrings.labelTitle(AcousticLabel.unclearRecording)),
      findsOneWidget,
    );
    expect(find.text(AcousticStrings.unclearTipsTitle), findsOneWidget);
    for (final tip in AcousticStrings.unclearTips) {
      expect(find.textContaining(tip), findsOneWidget);
    }
    expect(find.text(AcousticStrings.saveResult), findsNothing);
    expect(find.text(AcousticStrings.recordAgain), findsOneWidget);

    await tester.ensureVisible(find.text(AcousticStrings.recordAgain));
    await tester.tap(find.text(AcousticStrings.recordAgain));
    await tester.pump();
    expect(recordAgainCalls, 1);
  });

  testWidgets('a low-confidence result is also shown as unclear', (
    tester,
  ) async {
    await pumpResult(
      tester,
      service: FakeAcousticService(),
      result: testResult(confidence: 0.3),
      onRecordAgain: () {},
    );

    expect(find.text(AcousticStrings.unclearTipsTitle), findsOneWidget);
    expect(find.text(AcousticStrings.saveResult), findsNothing);
  });

  testWidgets('the waveform preview is hidden when there are no samples', (
    tester,
  ) async {
    await pumpResult(
      tester,
      service: FakeAcousticService(),
      result: testResult(),
      waveform: const [],
      onRecordAgain: () {},
    );

    expect(find.byType(WaveformView), findsNothing);
  });

  testWidgets('the waveform preview is shown when samples exist', (
    tester,
  ) async {
    await pumpResult(
      tester,
      service: FakeAcousticService(),
      result: testResult(),
      waveform: List<double>.filled(40, 0.4),
      onRecordAgain: () {},
    );

    expect(find.byType(WaveformView), findsOneWidget);
  });

  testWidgets('Record Again is hidden when no callback is supplied', (
    tester,
  ) async {
    await pumpResult(
      tester,
      service: FakeAcousticService(),
      result: testResult(),
    );

    expect(find.text(AcousticStrings.recordAgain), findsNothing);
  });
}
