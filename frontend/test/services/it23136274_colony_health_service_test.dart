// IT23136274 colony health service tests. All HTTP responses are SIMULATED
// with MockClient; no backend or Firestore is contacted.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/models/it23136274_sensor_anomaly_result.dart';
import 'package:frontend/models/sensor_reading_model.dart';
import 'package:frontend/services/it23136274_colony_health_service.dart';

Map<String, dynamic> _simulatedResponse({required String readingId, int prediction = -1}) => {
      'hive_id': 'HIVE_TEST',
      'reading_id': readingId,
      'timestamp': '2026-10-20T15:35:51.831729+00:00',
      'source': 'firestore_latest',
      'temperature': 28.3,
      'humidity': 84.3,
      'model_prediction': prediction,
      'status': prediction == 1
          ? SensorAnomalyResult.normalStatus
          : SensorAnomalyResult.inspectionStatus,
      'recommendation': 'simulated recommendation',
      'model': 'Isolation Forest V2',
      'note': 'Experimental. This prediction does not confirm colony health.',
    };

SensorReading _reading(String id) => SensorReading(id: id, hiveId: 'HIVE_TEST');

/// Counts requests and answers with [respond].
MockClient _mockClient(List<Uri> requests, http.Response Function(http.Request) respond) =>
    MockClient((request) async {
      requests.add(request.url);
      return respond(request);
    });

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('parses the backend prediction contract', () {
    final result = SensorAnomalyResult.fromJson(_simulatedResponse(readingId: 'r1'));
    expect(result.status, 'Inspection Recommended');
    expect(result.inspectionRecommended, isTrue);
    expect(result.temperature, 28.3);
    expect(result.humidity, 84.3);
    expect(result.timestamp, isNotNull);
  });

  test('calls the latest-prediction endpoint for the hive', () async {
    final requests = <Uri>[];
    final client = _mockClient(
        requests, (_) => http.Response(jsonEncode(_simulatedResponse(readingId: 'r1')), 200));
    final result = await http.runWithClient(
        () => ColonyHealthService.instance.fetchLatestPrediction('HIVE_TEST'), () => client);
    expect(result!.status, 'Inspection Recommended');
    expect(requests.single.path, endsWith('/colony-health/sensor-anomaly/latest/HIVE_TEST'));
  });

  test('404 means no readings; other errors surface the backend detail', () async {
    final requests = <Uri>[];
    await http.runWithClient(() async {
      expect(await ColonyHealthService.instance.fetchLatestPrediction('EMPTY'), isNull);
    }, () => _mockClient(requests, (_) => http.Response('{"detail":"none"}', 404)));

    await http.runWithClient(() async {
      await expectLater(
        ColonyHealthService.instance.fetchLatestPrediction('HIVE_TEST'),
        throwsA(isA<ColonyHealthException>()
            .having((e) => e.message, 'message', 'Model file not found')),
      );
    }, () => _mockClient(requests, (_) => http.Response('{"detail":"Model file not found"}', 503)));
  });

  test('controller calls the API once per new reading, not per repeated event', () async {
    final requests = <Uri>[];
    var nextId = 'r1';
    final client = _mockClient(
        requests, (_) => http.Response(jsonEncode(_simulatedResponse(readingId: nextId)), 200));

    await http.runWithClient(() async {
      final controller = SensorAnomalyController('HIVE_DEDUPE');
      controller.onReading(_reading('r1'));
      controller.onReading(_reading('r1')); // stream re-emits the same reading
      await _settle();
      expect(requests, hasLength(1));
      expect(controller.result!.readingId, 'r1');

      // A second screen for the same reading shares the cached request.
      final second = SensorAnomalyController('HIVE_DEDUPE');
      second.onReading(_reading('r1'));
      await _settle();
      expect(requests, hasLength(1));

      nextId = 'r2';
      controller.onReading(_reading('r2')); // a new reading arrives
      await _settle();
      expect(requests, hasLength(2));
      expect(controller.result!.readingId, 'r2');

      controller.dispose();
      second.dispose();
    }, () => client);
  });

  test('controller shows an error, and retry calls the API again', () async {
    final requests = <Uri>[];
    var fail = true;
    final client = _mockClient(
      requests,
      (_) => fail
          ? http.Response('{"detail":"Firestore query failed"}', 500)
          : http.Response(jsonEncode(_simulatedResponse(readingId: 'r1', prediction: 1)), 200),
    );

    await http.runWithClient(() async {
      final controller = SensorAnomalyController('HIVE_RETRY');
      controller.onReading(_reading('r1'));
      await _settle();
      expect(controller.error, 'Firestore query failed');
      expect(controller.loading, isFalse);

      fail = false;
      controller.retry();
      await _settle();
      expect(requests, hasLength(2));
      expect(controller.error, isNull);
      expect(controller.result!.status, 'Normal Sensor Pattern');
      controller.dispose();
    }, () => client);
  });

  test('a null reading shows the no-data state without calling the API', () async {
    final requests = <Uri>[];
    await http.runWithClient(() async {
      final controller = SensorAnomalyController('HIVE_NONE');
      controller.onReading(null);
      await _settle();
      expect(requests, isEmpty);
      expect(controller.noReadings, isTrue);
      expect(controller.result, isNull);
      controller.dispose();
    }, () => _mockClient(requests, (_) => http.Response('{}', 200)));
  });
}
