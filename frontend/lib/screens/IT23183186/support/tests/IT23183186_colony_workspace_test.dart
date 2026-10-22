import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:frontend/utils/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/screens/IT23183186_colony_workspace_screen.dart';
import 'package:frontend/services/IT23183186_workspace_api.dart';

import 'IT23183186_hive_environment_screen_test.dart' show hive, yard;

class WorkspaceFixture extends ColonyWorkspaceApi {
  bool fail = false;
  final observations = <Map<String, dynamic>>[];
  final plans = <Map<String, dynamic>>[];
  final reviews = <Map<String, dynamic>>[];
  final prefs = <String, dynamic>{
    'auto_refresh': false,
    'refresh_seconds': 300,
    'in_app_alerts': true,
  };
  @override
  Future<Map<String, dynamic>> load(String hiveId) async {
    if (fail) throw Exception('offline');
    return {
      'observations': observations,
      'care_plans': plans,
      'alert_reviews': reviews,
      'preferences': prefs,
      'models': {
        'model_a': {'available': false},
        'model_b': {'available': false},
      },
      'records': [],
      'sensor_history': [
        {
          'timestamp': '2026-10-21T10:00:00Z',
          'temperature': 34,
          'humidity': 65,
          'weight': 20,
        },
        {
          'timestamp': '2026-10-21T11:00:00Z',
          'temperature': 35,
          'humidity': 70,
          'weight': 21,
        },
      ],
      'monitoring': {
        'sensor': {
          'temperature': 35,
          'humidity': 70,
          'weight': 21,
          'timestamp': '2026-10-21T11:00:00Z',
        },
        'assessment': {
          'status': 'preliminary',
          'environmental_risk': 'watch',
          'disease_risk': 'inconclusive',
          'evidence': {'weather': 'fresh', 'sensors': 'fresh'},
          'missing_inputs': ['image evidence'],
          'alerts': [
            {
              'id': 'rain',
              'source': 'WeatherAPI',
              'severity': 'warning',
              'message': 'Review rainfall.',
              'review_key': 'a' * 64,
            },
          ],
        },
      },
    };
  }

  @override
  Future<Map<String, dynamic>> observe(
    String hiveId,
    Map<String, dynamic> data,
  ) async {
    observations.add({...data, 'id': 'observation-1'});
    return {};
  }

  @override
  Future<Map<String, dynamic>> plan(
    String hiveId,
    Map<String, dynamic> data,
  ) async {
    plans.add({...data, 'id': 'plan-1', 'status': 'planned'});
    return {};
  }

  @override
  Future<Map<String, dynamic>> complete(String hiveId, String planId) async {
    plans.first['status'] = 'completed';
    return {};
  }

  @override
  Future<Map<String, dynamic>> review(String hiveId, String key) async {
    reviews.add({'key': key});
    return {};
  }

  @override
  Future<Map<String, dynamic>> preferences(
    String hiveId,
    Map<String, dynamic> data,
  ) async {
    prefs.addAll(data);
    return {};
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> open(
  WidgetTester tester,
  WorkspaceFixture api, {
  String tab = 'Overview',
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('colony-preview'),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: IT23183186ColonyWorkspaceScreen(
          hive: hive,
          apiary: yard(),
          api: api,
          initialTab: tab,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> capturePreview(WidgetTester tester) async {
  await tester.runAsync(() async {
    await GoogleFonts.pendingFonts();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('colony-preview')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('build/IT23183186_colony_workspace_preview.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final width in [320.0, 1000.0]) {
    testWidgets(
      'all colony tabs fit width $width with true unavailable model states',
      (tester) async {
        final api = WorkspaceFixture();
        await open(tester, api, width: width);
        expect(find.text('Model A: unavailable'), findsOneWidget);
        if (const bool.fromEnvironment('COLONY_PREVIEW') && width == 1000) {
          await capturePreview(tester);
        }
        for (final tab in [
          'Observations',
          'Trends',
          'Alerts',
          'Care',
          'Images',
          'Settings',
        ]) {
          final chip = find.widgetWithText(ChoiceChip, tab);
          await reveal(tester, chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Background push notifications'), findsOneWidget);
      },
    );
  }
  testWidgets('record observations form saves into selected hive history', (
    tester,
  ) async {
    final api = WorkspaceFixture();
    await open(tester, api);
    await tester.tap(find.text('Record observations'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Save observation'));
    await tester.tap(find.text('Save observation'));
    await tester.pumpAndSettle();
    expect(
      find.text('Record at least one observation before saving.'),
      findsOneWidget,
    );
    await reveal(tester, field('Inspection notes'));
    await tester.enterText(
      field('Inspection notes'),
      'Food stores checked during visit',
    );
    await reveal(tester, find.text('Save observation'));
    await tester.tap(find.text('Save observation'));
    await tester.pumpAndSettle();
    expect(api.observations.length, 1);
    expect(find.text('Food stores checked during visit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('care plan saves and completion persists', (tester) async {
    final api = WorkspaceFixture();
    await open(tester, api, tab: 'Care');
    await tester.tap(find.text('Plan hive care'));
    await tester.pumpAndSettle();
    await reveal(tester, field('Plan and follow-up notes'));
    await tester.enterText(
      field('Plan and follow-up notes'),
      'Review stores at next visit',
    );
    await reveal(tester, find.text('Save care plan'));
    await tester.tap(find.text('Save care plan'));
    await tester.pumpAndSettle();
    expect(api.plans.single['status'], 'planned');
    await reveal(tester, find.text('Mark completed'));
    await tester.tap(find.text('Mark completed'));
    await tester.pumpAndSettle();
    expect(api.plans.single['status'], 'completed');
    expect(find.text('Status: completed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('alert review and monitoring preferences persist', (
    tester,
  ) async {
    final api = WorkspaceFixture();
    await open(tester, api, tab: 'Alerts');
    await reveal(tester, find.text('Mark reviewed'));
    await tester.tap(find.text('Mark reviewed'));
    await tester.pumpAndSettle();
    expect(api.reviews.length, 1);
    expect(find.text('Mark reviewed'), findsNothing);
    final settings = find.widgetWithText(ChoiceChip, 'Settings');
    await reveal(tester, settings);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(
      SwitchListTile,
      'In-app alert summaries',
    );
    await reveal(tester, toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(api.prefs['in_app_alerts'], false);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'workspace load failure offers retry without fabricated readings',
    (tester) async {
      final api = WorkspaceFixture()..fail = true;
      await open(tester, api);
      expect(
        find.textContaining('Colony records could not be loaded'),
        findsOneWidget,
      );
      api.fail = false;
      await reveal(tester, find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Weight (kg): 21'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
