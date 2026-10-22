import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/services/environment_fallback.dart';
import 'package:frontend/services/image_inference_api.dart';
import 'package:frontend/services/weather_service.dart';
import 'package:frontend/services/IT23183186_colony_assessment_api.dart';
import 'package:frontend/services/IT23183186_workspace_api.dart';
import 'package:frontend/widgets/environment_source.dart';
import 'package:frontend/utils/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> fixtures;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EnvironmentFallback.instance.clearSession();
    fixtures = jsonDecode(
      File('assets/demo/environment_disease_demo.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });
  test('offline demo, restored live, then cached actual retains origin and capture time', () async {
    fixtures['example'] = {'value': 7};
    final store = EnvironmentFallback(
      scopeOverride: 'user-a',
      fixtureLoader: () async => fixtures,
    );
    var online = false;
    Future<Map<String, dynamic>> live() async {
      if (!online) throw const SocketException('offline');
      return {'value': 42};
    }

    expect(dataSource(await store.read('example', live, 'example')), 'demo');
    online = true;
    final actual = await store.read('example', live, 'example');
    expect(dataSource(actual), 'live');
    expect(actual['value'], 42);
    online = false;
    final cached = await store.read('example', live, 'example');
    expect(dataSource(cached), 'cached');
    expect(cached['_retrieved_at'], actual['_retrieved_at']);
    final restarted = EnvironmentFallback(
      scopeOverride: 'user-a',
      fixtureLoader: () async => fixtures,
    );
    expect(
      dataSource(await restarted.read('example', live, 'example')),
      'cached',
    );
    final other = EnvironmentFallback(
      scopeOverride: 'user-b',
      fixtureLoader: () async => fixtures,
    );
    expect(dataSource(await other.read('example', live, 'example')), 'demo');
  });
  test(
    'access and validation failures are never turned into fake success',
    () async {
      final store = EnvironmentFallback(
        scopeOverride: 'u',
        fixtureLoader: () async => fixtures,
      );
      for (final status in [400, 401, 403, 404, 413, 415, 422]) {
        await expectLater(
          store.read(
            'validation',
            () async => throw EnvironmentRequestFailure('rejected', status),
            'monitoring',
          ),
          throwsA(isA<EnvironmentRequestFailure>()),
        );
      }
    },
  );
  test('local demo saves survive restart, deduplicate, and never enter actual cache', () async {
    final store = EnvironmentFallback(
      scopeOverride: 'u',
      fixtureLoader: () async => fixtures,
    );
    final data = await store.fixture('monitoring');
    final saved = await store.saveLocal('demo-hive-1', data);
    final repeated = await store.saveLocal('demo-hive-1', data);
    expect(saved['id'], repeated['id']);
    expect(saved['local_only'], true);
    final restarted = EnvironmentFallback(
      scopeOverride: 'u',
      fixtureLoader: () async => fixtures,
    );
    final records = await restarted.localRecords('demo-hive-1');
    expect(records.length, 1);
    expect(dataSource(records.single), 'demo');
    expect(
      (await SharedPreferences.getInstance()).getKeys().any(
        (k) => k.startsWith('environment_actual_'),
      ),
      false,
    );
  });
  test('offline weather, forecast, and history deserialize complete labelled fixtures', () async {
    final service = WeatherService(
      client: MockClient((_) async => throw const SocketException('offline')),
    );
    expect((await service.fetchCurrent('Kandy')).source, 'demo');
    expect((await service.fetchImpact('Kandy')).analysis.source, 'demo');
    expect((await service.fetchForecast('Kandy')).source, 'demo');
    final history = await service.fetchHistoryAnalysis('Kandy');
    expect(history.days.length, 7);
    expect(history.days.first.source, 'demo');
  });
  test('partial monitoring keeps actual assessment and weather while sensor example is demo', () async {
    final real = {...fixtures['monitoring'] as Map, 'sensor': null};
    final service = ColonyAssessmentApi(
      tokenOverride: 'test',
      client: MockClient((_) async => http.Response(jsonEncode(real), 200)),
    );
    final result = await service.fetch(location: 'Kandy', hiveId: 'owned-hive');
    expect(dataSource(result['assessment'] as Map), 'live');
    expect(dataSource(result['weather'] as Map), 'live');
    expect(dataSource(result['sensor'] as Map), 'demo');
  });
  test('actual inference is preserved when only the other model fails; invalid upload stays invalid', () async {
    final bytes = File('lib/utils/images/05_bees_on_honeycomb.png')
        .readAsBytesSync();
    final file = XFile.fromData(bytes, name: 'bee.png');
    final api = ImageInferenceApi(
      tokenOverride: 'test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'model_a': {
              'status': 'complete',
              'predicted_class': 'healthy',
              'class_scores': {'healthy': .91, 'varroa_positive': .09},
              'inference_duration_ms': 37.5,
            },
            'model_b': {'status': 'error'},
            'assessment': {},
          }),
          200,
        ),
      ),
    );
    final result = await api.analyze(outsideImage: file, insideImage: file);
    expect(result['model_a']['class_scores']['healthy'], .91);
    expect(result['model_a']['inference_duration_ms'], 37.5);
    expect(dataSource(result['model_a'] as Map), 'live');
    expect(dataSource(result['model_b'] as Map), 'demo');
    await expectLater(
      api.analyze(
        outsideImage: XFile.fromData(
          Uint8List.fromList([1, 2]),
          name: 'bad.png',
        ),
      ),
      throwsA(isA<ImageInferenceException>()),
    );
  });
  test('offline image example does not claim to analyze an arbitrary upload; local save only', () async {
    final api = ImageInferenceApi(
      tokenOverride: 'test',
      client: MockClient((_) async => throw const SocketException('offline')),
    );
    final file = XFile.fromData(
      File('lib/utils/images/05_bees_on_honeycomb.png').readAsBytesSync(),
    );
    final result = await api.analyze(
      outsideImage: file,
      hiveId: 'owned-hive',
      saveResult: true,
    );
    expect(dataSource(result['model_a'] as Map), 'demo');
    expect(result['model_a']['demo_image_asset'], isNotNull);
    expect(result['saved_record_id'], isNull);
    expect(result['local_saved_record_id'], isNotNull);
  });
  test('missing evaluation stays empty; malformed report falls back without made-up metrics', () async {
    var malformed = false;
    final api = ImageInferenceApi(
      tokenOverride: 'test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(
            malformed ? {} : {'summary': {}, 'history': [], 'evaluation': null},
          ),
          200,
        ),
      ),
    );
    expect((await api.fetchModelReport('model_a'))['evaluation'], isNull);
    EnvironmentFallback.instance.clearSession();
    SharedPreferences.setMockInitialValues({});
    malformed = true;
    final report = await api.fetchModelReport('model_a');
    expect(dataSource(report), 'demo');
    expect(report['evaluation'], isNull);
    expect(report['history'], isEmpty);
  });
  test('demo workspace changes persist locally and never POST to a demo identifier', () async {
    var calls = 0;
    final api = ColonyWorkspaceApi(
      tokenOverride: 'test',
      client: MockClient((_) async {
        calls++;
        throw const SocketException('offline');
      }),
    );
    final saved = await api.observe('demo-hive-1', {
      'notes': 'Demo observation',
    });
    expect(saved['local_only'], true);
    expect(calls, 0);
    final data = await api.load('demo-hive-1');
    expect((data['observations'] as List).first['notes'], 'Demo observation');
    await api.complete('demo-hive-1', 'demo-plan');
    final updated = await api.load('demo-hive-1');
    expect((updated['care_plans'] as List).first['status'], 'completed');
  });
  testWidgets(
    'visible fallback recovers automatically and stops retrying once actual data returns',
    (tester) async {
      final source = ValueNotifier<String>('demo');
      var attempts = 0;
      EnvironmentFallback.instance.markSource('recovery-test', 'demo');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: source,
              builder: (context, value, child) => EnvironmentRecovery(
                needed: () => value == 'demo',
                onRetry: () async {
                  attempts++;
                  source.value = 'live';
                  EnvironmentFallback.instance.markSource(
                    'recovery-test',
                    'live',
                  );
                },
                child: SourceDot(source: value),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Demo data'), findsOneWidget);
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(find.text('Actual data'), findsOneWidget);
      expect(attempts, 1);
      await tester.pump(const Duration(seconds: 21));
      expect(attempts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      source.dispose();
    },
  );

  testWidgets(
    'source indicators use red for actual, black for demo, and name cached records',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SourceDot(source: 'live'),
                SourceDot(source: 'demo'),
                SourceDot(source: 'cached'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Actual data'), findsOneWidget);
      expect(find.text('Demo data'), findsOneWidget);
      expect(find.text('Saved actual data'), findsOneWidget);
      final colors = tester
          .widgetList<Container>(find.byType(Container))
          .map(
            (c) => (c.decoration is BoxDecoration)
                ? (c.decoration as BoxDecoration).color
                : null,
          )
          .toList();
      expect(colors, contains(AppColors.error));
      expect(colors, contains(AppColors.panelBlack));
    },
  );
}
