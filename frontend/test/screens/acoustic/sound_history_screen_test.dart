import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/acoustic/acoustic_strings.dart';
import 'package:frontend/models/acoustic/acoustic_result.dart';
import 'package:frontend/screens/acoustic/hive_sound_monitor_screen.dart';
import 'package:frontend/screens/acoustic/sound_history_screen.dart';
import 'package:frontend/widgets/acoustic/history_filter_sheet.dart';

import '../../support/acoustic/fake_acoustic_service.dart';

final DateTime _now = DateTime.now();

AcousticResult saved(
  String id,
  AcousticLabel label,
  Duration ago, {
  String hiveId = 'H-001',
}) {
  return AcousticResult(
    id: id,
    hiveId: hiveId,
    label: label,
    confidence: 0.9,
    recordedAt: _now.subtract(ago),
    audioQuality: AudioQuality.good,
    modelVersion: 'test',
  );
}

Future<void> pumpHistory(
  WidgetTester tester, {
  required FakeAcousticService service,
  String hiveId = 'H-001',
  Future<void> Function(String hiveId)? onRecordPressed,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: SoundHistoryScreen(
        service: service,
        hiveId: hiveId,
        onRecordPressed: onRecordPressed,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> chooseFilter(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip(AcousticStrings.filterTooltip));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, title));
  await tester.pumpAndSettle();
}

void main() {
  group('order', () {
    testWidgets('lists newest first, whatever order the service returns', (
      tester,
    ) async {
      final service = FakeAcousticService(
        history: [
          saved('a', AcousticLabel.swarming, const Duration(hours: 3)),
          saved('b', AcousticLabel.queenless, const Duration(days: 2)),
          saved('c', AcousticLabel.normal, const Duration(hours: 1)),
        ],
      );
      await pumpHistory(tester, service: service);

      final normal = tester.getTopLeft(find.text('Queen Present')).dy;
      final swarming = tester.getTopLeft(find.text('Swarming Pattern')).dy;
      final queenless = tester.getTopLeft(find.text('Queenless')).dy;
      expect(normal, lessThan(swarming));
      expect(swarming, lessThan(queenless));
    });

    testWidgets('shows only the selected hive', (tester) async {
      final service = FakeAcousticService(
        history: [
          saved('a', AcousticLabel.normal, const Duration(hours: 1)),
          saved(
            'b',
            AcousticLabel.swarming,
            const Duration(hours: 2),
            hiveId: 'H-002',
          ),
        ],
      );
      await pumpHistory(tester, service: service);

      expect(find.text('Queen Present'), findsOneWidget);
      expect(find.text('Swarming Pattern'), findsNothing);
    });
  });

  group('filter', () {
    testWidgets('filtering by status shows only that status and Show all '
        'clears it', (tester) async {
      final service = FakeAcousticService(
        history: [
          saved('a', AcousticLabel.normal, const Duration(hours: 1)),
          saved('b', AcousticLabel.swarming, const Duration(hours: 2)),
        ],
        isDemo: true,
      );
      await pumpHistory(tester, service: service);

      await chooseFilter(tester, 'Swarming Pattern');
      expect(find.text('Queen Present'), findsNothing);
      expect(find.text('Swarming Pattern'), findsOneWidget);
      expect(find.text('Showing: Swarming Pattern'), findsOneWidget);

      await tester.tap(find.text(AcousticStrings.showAll));
      await tester.pumpAndSettle();
      expect(find.text('Queen Present'), findsOneWidget);
      expect(find.text('Swarming Pattern'), findsOneWidget);
    });

    testWidgets('a filter with no matches says so', (tester) async {
      final service = FakeAcousticService(
        history: [saved('a', AcousticLabel.normal, const Duration(hours: 1))],
      );
      await pumpHistory(tester, service: service);

      await chooseFilter(tester, 'Queenless');
      expect(find.text(AcousticStrings.noMatchingAnalyses), findsOneWidget);
    });

    testWidgets('every option in the sheet has a name, not only a colour', (
      tester,
    ) async {
      final service = FakeAcousticService(
        history: [saved('a', AcousticLabel.normal, const Duration(hours: 1))],
        isDemo: true,
      );
      await pumpHistory(tester, service: service);
      await tester.tap(find.byTooltip(AcousticStrings.filterTooltip));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryFilterSheet), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'All'), findsOneWidget);
      for (final label in HistoryFilterSheet.filterLabels) {
        expect(
          find.widgetWithText(ListTile, AcousticStrings.labelTitle(label)),
          findsOneWidget,
        );
      }
      expect(
        find.widgetWithText(ListTile, 'Unclear Recording'),
        findsNothing,
        reason: 'unclear results are never saved, so they are not a filter',
      );
    });
  });

  group('states', () {
    testWidgets('empty state offers Record, which calls back for the hive', (
      tester,
    ) async {
      String? recordedFor;
      await pumpHistory(
        tester,
        service: FakeAcousticService(),
        onRecordPressed: (hiveId) async => recordedFor = hiveId,
      );

      expect(find.text(AcousticStrings.noSavedAnalysesForHive), findsOneWidget);
      await tester.tap(find.text(AcousticStrings.recordHiveSound));
      await tester.pumpAndSettle();
      expect(recordedFor, 'H-001');
    });

    testWidgets('empty state hides Record when no callback is given', (
      tester,
    ) async {
      await pumpHistory(tester, service: FakeAcousticService());

      expect(find.text(AcousticStrings.noSavedAnalysesForHive), findsOneWidget);
      expect(find.text(AcousticStrings.recordHiveSound), findsNothing);
    });

    testWidgets('error shows a message, and Try Again reloads the list', (
      tester,
    ) async {
      final service = FakeAcousticService(
        historyFailures: 1,
        history: [saved('a', AcousticLabel.normal, const Duration(hours: 1))],
      );
      await pumpHistory(tester, service: service);

      expect(find.text(AcousticStrings.historyLoadFailed), findsOneWidget);
      expect(find.text('Queen Present'), findsNothing);

      await tester.tap(find.text(AcousticStrings.tryAgain));
      await tester.pumpAndSettle();

      expect(service.historyCalls, 2);
      expect(find.text(AcousticStrings.historyLoadFailed), findsNothing);
      expect(find.text('Queen Present'), findsOneWidget);
    });
  });

  group('opening a result', () {
    testWidgets('tapping a row opens the Result read-only, with back only', (
      tester,
    ) async {
      final service = FakeAcousticService(
        history: [
          saved('a', AcousticLabel.queenless, const Duration(hours: 1)),
        ],
      );
      await pumpHistory(tester, service: service);

      await tester.tap(find.text('Queenless'));
      await tester.pumpAndSettle();

      expect(find.text(AcousticStrings.analysisResultTitle), findsOneWidget);
      expect(find.text(AcousticStrings.saveResult), findsNothing);
      expect(find.text(AcousticStrings.recordAgain), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(AcousticStrings.soundHistoryTitle), findsOneWidget);
    });
  });

  group('saved results', () {
    testWidgets('a result saved for this hive appears in history', (
      tester,
    ) async {
      final service = FakeAcousticService();
      await service.saveResult(
        saved('new', AcousticLabel.swarming, const Duration(minutes: 5)),
      );
      await service.saveResult(
        saved(
          'other',
          AcousticLabel.normal,
          const Duration(minutes: 5),
          hiveId: 'H-002',
        ),
      );
      await pumpHistory(tester, service: service);

      expect(find.text('Swarming Pattern'), findsOneWidget);
      expect(find.text('Queen Present'), findsNothing);
    });

    testWidgets('the Monitor history icon opens Sound History', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: HiveSoundMonitorScreen(service: FakeAcousticService()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(AcousticStrings.soundHistoryTooltip));
      await tester.pumpAndSettle();
      expect(find.text(AcousticStrings.soundHistoryTitle), findsOneWidget);
    });
  });

  group('abnormality trend card', () {
    /// Saved result on the calendar day [daysAgo] before today.
    AcousticResult onDay(
      String id,
      AcousticLabel label,
      int daysAgo, {
      String hiveId = 'H-001',
    }) {
      return AcousticResult(
        id: id,
        hiveId: hiveId,
        label: label,
        confidence: 0.9,
        recordedAt: DateTime(_now.year, _now.month, _now.day - daysAgo, 12),
        audioQuality: AudioQuality.good,
        modelVersion: 'test',
      );
    }

    testWidgets('shows the title and a count on each abnormal day', (
      tester,
    ) async {
      final service = FakeAcousticService(
        history: [
          onDay('a', AcousticLabel.swarming, 0),
          onDay('b', AcousticLabel.normal, 0),
          onDay('c', AcousticLabel.queenless, 2),
          // Another hive, so it must not add to this one.
          onDay('d', AcousticLabel.swarming, 0, hiveId: 'H-002'),
        ],
      );
      await pumpHistory(tester, service: service);

      expect(find.text(AcousticStrings.abnormalTrendTitle(7)), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2), reason: 'today and 2 days ago');
      expect(find.text(AcousticStrings.noAbnormalThisWeek), findsNothing);
    });

    testWidgets('says so when nothing abnormal happened this week', (
      tester,
    ) async {
      final service = FakeAcousticService(
        history: [
          onDay('a', AcousticLabel.normal, 0),
          // Outside the window, so it does not count.
          onDay('b', AcousticLabel.swarming, 8),
        ],
      );
      await pumpHistory(tester, service: service);

      expect(find.text(AcousticStrings.noAbnormalThisWeek), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('a long list at 360 x 640 has no overflow and scrolls', (
      tester,
    ) async {
      final service = FakeAcousticService(
        history: [
          for (var i = 0; i < 30; i++)
            saved(
              'n$i',
              AcousticLabel.values[i % AcousticLabel.values.length],
              Duration(hours: i + 1),
            ),
        ],
      );
      await pumpHistory(tester, service: service, size: const Size(360, 640));
      expect(tester.takeException(), isNull);

      // The first row is visible; the last one is only reached by scrolling.
      expect(find.text('Queen Present'), findsWidgets);
      // The list is lazy, so the last rows only exist once it is scrolled.
      await tester.fling(find.byType(ListView), const Offset(0, -4000), 5000);
      await tester.pumpAndSettle();
      expect(find.text('Unclear Recording'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the real model offers only labels it can predict', (
      tester,
    ) async {
      final service = FakeAcousticService(
        history: [saved('a', AcousticLabel.normal, const Duration(hours: 1))],
      );
      await pumpHistory(tester, service: service);
      await tester.tap(find.byTooltip(AcousticStrings.filterTooltip));
      await tester.pumpAndSettle();

      for (final title in [
        'All',
        'Queen Present',
        'Queenless',
        'Unclear Recording',
      ]) {
        expect(find.widgetWithText(ListTile, title), findsOneWidget);
      }
      expect(find.widgetWithText(ListTile, 'Swarming Pattern'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Abnormal Activity'), findsNothing);
    });

    testWidgets('the filter sheet and empty states fit at 360 px', (
      tester,
    ) async {
      final service = FakeAcousticService(
        history: [saved('a', AcousticLabel.normal, const Duration(hours: 1))],
        isDemo: true,
      );
      await pumpHistory(tester, service: service, size: const Size(360, 640));

      await chooseFilter(tester, 'Swarming Pattern');
      expect(tester.takeException(), isNull);
      expect(find.text(AcousticStrings.noMatchingAnalyses), findsOneWidget);
    });
  });
}
