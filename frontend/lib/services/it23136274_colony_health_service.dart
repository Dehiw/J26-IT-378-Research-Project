import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/it23136274_sensor_anomaly_result.dart';
import '../models/sensor_reading_model.dart';
import '../utils/api_config.dart';

class ColonyHealthException implements Exception {
  final String message;
  const ColonyHealthException(this.message);

  @override
  String toString() => message;
}

/// IT23136274 - Client for the colony health sensor anomaly API.
class ColonyHealthService {
  static final ColonyHealthService instance = ColonyHealthService._internal();
  ColonyHealthService._internal();

  /// Latest request per hive, keyed by the reading that triggered it, so
  /// rebuilds and multiple screens share one API call per new reading.
  final Map<String, ({String readingId, Future<SensorAnomalyResult?> future})> _latestByHive = {};

  /// Prediction for the latest reading of [hiveId], requested at most once per [readingId].
  Future<SensorAnomalyResult?> predictionForReading(String hiveId, String readingId) {
    final cached = _latestByHive[hiveId];
    if (cached != null && cached.readingId == readingId) return cached.future;

    final future = fetchLatestPrediction(hiveId);
    _latestByHive[hiveId] = (readingId: readingId, future: future);
    // Forget failed requests so a retry calls the API again.
    future.then((_) {}, onError: (Object _) {
      if (identical(_latestByHive[hiveId]?.future, future)) _latestByHive.remove(hiveId);
    });
    return future;
  }

  /// Runs the model on the hive's latest Firestore reading.
  /// Returns null when the hive has no sensor readings.
  Future<SensorAnomalyResult?> fetchLatestPrediction(String hiveId) async {
    final url =
        '${ApiConfig.baseUrl}/colony-health/sensor-anomaly/latest/${Uri.encodeComponent(hiveId)}';
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'accept': 'application/json',
      }).timeout(const Duration(seconds: 12));
      if (response.statusCode == 404) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ColonyHealthException(json['detail']?.toString() ?? 'Prediction request failed');
      }
      return SensorAnomalyResult.fromJson(json);
    } catch (e) {
      developer.log('Failed to fetch sensor anomaly prediction: $e', name: 'ColonyHealthService');
      throw _toException(e);
    }
  }

  ColonyHealthException _toException(Object error) {
    if (error is ColonyHealthException) return error;
    if (error is http.ClientException) {
      return const ColonyHealthException('Cannot connect to backend server.');
    }
    if (error is TimeoutException) {
      return const ColonyHealthException('Backend request timed out.');
    }
    if (error is FormatException) {
      return const ColonyHealthException('Unexpected response from backend server.');
    }
    return ColonyHealthException(error.toString());
  }
}

/// Screen-side state for the sensor anomaly card.
///
/// Feed it every reading from [SensorReadingService.streamLatestReading];
/// it only calls the API when the reading ID changes.
class SensorAnomalyController extends ChangeNotifier {
  SensorAnomalyController(this.hiveId, {ColonyHealthService? service})
      : _service = service ?? ColonyHealthService.instance;

  final String hiveId;
  final ColonyHealthService _service;

  SensorAnomalyResult? result;
  bool loading = false;
  String? error;

  /// True once the sensor stream reported that the hive has no readings.
  bool noReadings = false;

  SensorReading? _reading;
  bool _disposed = false;

  void onReading(SensorReading? reading) {
    if (reading == null) {
      _reading = null;
      result = null;
      error = null;
      loading = false;
      noReadings = true;
      _notify();
      return;
    }
    // Same reading re-emitted (e.g. stream reconnect): nothing new to predict.
    if (reading.id == _reading?.id) return;
    _reading = reading;
    _predict(reading);
  }

  void retry() {
    final reading = _reading;
    if (reading != null) _predict(reading);
  }

  Future<void> _predict(SensorReading reading) async {
    noReadings = false;
    loading = true;
    error = null;
    _notify();
    try {
      final prediction = await _service.predictionForReading(hiveId, reading.id);
      if (_reading?.id != reading.id) return; // a newer reading arrived meanwhile
      result = prediction;
      noReadings = prediction == null;
    } catch (e) {
      if (_reading?.id != reading.id) return;
      error = e.toString();
    }
    loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
