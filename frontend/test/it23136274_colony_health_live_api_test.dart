// IT23136274 live pipeline check: ESP32 readings in Firestore -> FastAPI ->
// Isolation Forest V2 -> Flutter services. Uses REAL data, so it only runs when
// the local backend is up. flutter test reports an Android platform, so pass
// API_BASE_URL or ApiConfig would use the emulator address 10.0.2.2:
//   flutter test test/it23136274_colony_health_live_api_test.dart \
//     --dart-define=IT23136274_LIVE_API=true --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/it23136274_sensor_anomaly_result.dart';
import 'package:frontend/services/it23136274_colony_health_service.dart';
import 'package:frontend/services/sensor_reading_service.dart';

const _live = bool.fromEnvironment('IT23136274_LIVE_API');

void main() {
  test(
    'latest real HIVE_001 reading streams in and gets a sensor anomaly prediction',
    () async {
      const hiveId = SensorReadingService.defaultHiveId;
      final reading = await SensorReadingService.instance
          .streamLatestReading(hiveId)
          .first
          .timeout(const Duration(seconds: 20));
      expect(reading, isNotNull, reason: 'HIVE_001 has no readings in Firestore');

      final controller = SensorAnomalyController(hiveId);
      controller.onReading(reading);
      while (controller.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      expect(controller.error, isNull);
      final result = controller.result!;
      expect(result.readingId, reading!.id);
      expect(result.temperature, reading.temperature);
      expect(result.humidity, reading.humidity);
      expect(
        result.status,
        anyOf(SensorAnomalyResult.normalStatus, SensorAnomalyResult.inspectionStatus),
      );
      // ignore: avoid_print
      print('LIVE ${result.hiveId} reading ${result.readingId} @ ${result.timestamp}: '
          '${result.temperature} °C, ${result.humidity} % -> ${result.status} '
          '(model_prediction ${result.modelPrediction})');
      controller.dispose();
    },
    skip: _live ? false : 'Pass --dart-define=IT23136274_LIVE_API=true with the backend running.',
  );
}
