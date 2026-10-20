import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

import '../models/sensor_reading_model.dart';
import '../utils/api_config.dart';

class SensorReadingException implements Exception {
  final String message;
  const SensorReadingException(this.message);

  @override
  String toString() => message;
}

/// Service for reading ESP32 sensor data.
///
/// The FastAPI backend runs Firestore snapshot listeners on `sensor_readings`
/// and pushes every change to the app as Server-Sent Events, so these streams
/// update automatically whenever the ESP32 saves a new reading.
class SensorReadingService {
  static final SensorReadingService instance = SensorReadingService._internal();
  SensorReadingService._internal();

  /// ESP32 device ID used until app hives are linked to sensor devices.
  static const String defaultHiveId = 'HIVE_001';

  static const Duration _retryDelay = Duration(seconds: 5);

  /// Maps an app hive ID to the ESP32 device ID stored in `hive_id`.
  /// App hive IDs are not yet linked to devices, so fall back to [defaultHiveId].
  static String resolveSensorHiveId(String appHiveId) =>
      appHiveId.startsWith('HIVE_') ? appHiveId : defaultHiveId;

  /// Live latest reading for [hiveId]; emits null when the hive has no readings.
  Stream<SensorReading?> streamLatestReading(String hiveId) {
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}/sensor-data/stream/latest/${Uri.encodeComponent(hiveId)}');
    return _sseEvents(uri).map((event) {
      final reading = event['reading'];
      return reading is Map<String, dynamic> ? SensorReading.fromJson(reading) : null;
    });
  }

  /// Live readings for [hiveId] with start <= timestamp (<= end), oldest first.
  /// Leave [end] null to keep receiving new readings as they arrive.
  Stream<List<SensorReading>> streamReadingsForRange(
    String hiveId,
    DateTime start, [
    DateTime? end,
  ]) {
    final uri = Uri.parse(
            '${ApiConfig.baseUrl}/sensor-data/stream/history/${Uri.encodeComponent(hiveId)}')
        .replace(queryParameters: {
      'start': start.toUtc().toIso8601String(),
      if (end != null) 'end': end.toUtc().toIso8601String(),
    });

    final byId = <String, SensorReading>{};
    return _sseEvents(uri).map((event) {
      if (event['type'] == 'reset') byId.clear();
      for (final json in (event['readings'] as List<dynamic>? ?? const [])) {
        if (json is! Map<String, dynamic>) continue;
        final reading = SensorReading.fromJson(json);
        byId[reading.id] = reading;
      }
      for (final id in (event['removed'] as List<dynamic>? ?? const [])) {
        byId.remove(id);
      }
      return byId.values.where((r) => r.timestamp != null).toList()
        ..sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
    });
  }

  /// Fetch the most recent reading once. Returns null if none exist.
  Future<SensorReading?> fetchLatestReading(String hiveId) async {
    final url = '${ApiConfig.baseUrl}/sensor-data/latest/${Uri.encodeComponent(hiveId)}';
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'accept': 'application/json',
      }).timeout(const Duration(seconds: 12));
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SensorReadingException(json['detail']?.toString() ?? 'Request failed');
      }
      final reading = json['reading'];
      if (reading == null) return null;
      return SensorReading.fromJson(reading as Map<String, dynamic>);
    } catch (e) {
      developer.log('Failed to fetch latest reading: $e', name: 'SensorReadingService');
      throw _toException(e);
    }
  }

  // ── Internal ───────────────────────────────────────────────────

  /// Opens a Server-Sent Events connection and emits each `data:` payload.
  /// Errors are emitted to the listener, then the connection is retried until
  /// the listener cancels.
  Stream<Map<String, dynamic>> _sseEvents(Uri uri) {
    late final StreamController<Map<String, dynamic>> controller;
    http.Client? client;
    StreamSubscription<String>? subscription;
    Timer? retryTimer;
    var cancelled = false;
    late Future<void> Function() connect;

    void scheduleRetry(Object error) {
      subscription?.cancel();
      client?.close();
      if (cancelled) return;
      developer.log('Sensor stream error: $error', name: 'SensorReadingService');
      controller.addError(_toException(error));
      retryTimer = Timer(_retryDelay, () {
        if (!cancelled) connect();
      });
    }

    connect = () async {
      final activeClient = http.Client();
      client = activeClient;
      try {
        final request = http.Request('GET', uri)
          ..headers['accept'] = 'text/event-stream';
        final response =
            await activeClient.send(request).timeout(const Duration(seconds: 15));
        if (cancelled) return activeClient.close();

        if (response.statusCode != 200) {
          final body = await response.stream.bytesToString();
          throw SensorReadingException(_errorDetail(body));
        }

        final data = StringBuffer();
        subscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (line) {
            if (line.startsWith('data:')) {
              data.write(line.substring(5).trimLeft());
            } else if (line.isEmpty && data.isNotEmpty) {
              final payload = data.toString();
              data.clear();
              final decoded = jsonDecode(payload);
              if (decoded is Map<String, dynamic>) controller.add(decoded);
            }
          },
          onError: scheduleRetry,
          onDone: () => scheduleRetry(
              const SensorReadingException('Live sensor connection closed.')),
          cancelOnError: true,
        );
      } catch (e) {
        scheduleRetry(e);
      }
    };

    controller = StreamController<Map<String, dynamic>>(
      onListen: connect,
      onCancel: () {
        cancelled = true;
        retryTimer?.cancel();
        subscription?.cancel();
        client?.close();
      },
    );
    return controller.stream;
  }

  String _errorDetail(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['detail'] != null) return json['detail'].toString();
    } catch (_) {}
    return 'Request failed';
  }

  SensorReadingException _toException(Object error) {
    if (error is SensorReadingException) return error;
    if (error is http.ClientException) {
      return const SensorReadingException('Cannot connect to backend server.');
    }
    if (error is TimeoutException) {
      return const SensorReadingException('Backend request timed out.');
    }
    return SensorReadingException(error.toString());
  }
}
