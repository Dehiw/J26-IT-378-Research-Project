import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/screens/IT23183186_hive_environment_screen.dart';
import 'package:frontend/screens/IT23183186_environment_history_screen.dart';

import 'IT23183186_hive_environment_screen_test.dart'
    show FakeAssessment, FakeWeather, hive, yard;

class RecordsApi extends FakeAssessment {
  String? savedHive;
  String? loadedHive;
  bool unavailable = false;
  final records = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> saveSnapshot({
    required String hiveId,
    String? location,
  }) async {
    savedHive = hiveId;
    if (unavailable) throw Exception('offline');
    final record = <String, dynamic>{
      'id': 'snapshot-1',
      'saved_at': '2026-10-21T09:00:00Z',
      'location_query': '7.2906,80.6337',
      'weather': null,
      'sensor': null,
      'assessment': {
        'status': 'inconclusive',
        'alerts': [],
        'missing_inputs': ['sensors'],
      },
    };
    records.add(record);
    return record;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchHistory(String hiveId) async {
    loadedHive = hiveId;
    if (unavailable) throw Exception('offline');
    return records;
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('save selected hive then open saved historical evidence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = RecordsApi();
    await tester.pumpWidget(
      MaterialApp(
        home: IT23183186HiveEnvironmentScreen(
          hive: hive,
          apiary: yard(),
          weatherService: FakeWeather(),
          assessmentApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save snapshot'));
    await tester.tap(find.text('Save snapshot'));
    await tester.pumpAndSettle();
    expect(api.savedHive, hive.id);
    expect(find.text('Snapshot saved to your hive history.'), findsOneWidget);
    await tester.ensureVisible(find.text('Saved history'));
    await tester.tap(find.text('Saved history'));
    await tester.pumpAndSettle();
    expect(api.loadedHive, hive.id);
    expect(find.text('Saved environment'), findsOneWidget);
    expect(
      find.text('Outdoor weather was unavailable when saved.'),
      findsOneWidget,
    );
    expect(find.textContaining('historical observations'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed write never reports saved', (tester) async {
    final api = RecordsApi()..unavailable = true;
    await tester.pumpWidget(
      MaterialApp(
        home: IT23183186HiveEnvironmentScreen(
          hive: hive,
          apiary: yard(),
          weatherService: FakeWeather(),
          assessmentApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save snapshot'));
    await tester.tap(find.text('Save snapshot'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Snapshot was not saved.'), findsOneWidget);
    expect(api.records, isEmpty);
  });

  testWidgets('history handles error, retry, and empty records', (
    tester,
  ) async {
    final api = RecordsApi()..unavailable = true;
    await tester.pumpWidget(
      MaterialApp(
        home: IT23183186EnvironmentHistoryScreen(
          hiveId: hive.id,
          hiveName: hive.name,
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not load saved history.'),
      findsOneWidget,
    );
    api.unavailable = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No snapshots saved yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
