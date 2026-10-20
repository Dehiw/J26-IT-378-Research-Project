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
/// Calls the FastAPI backend, which queries Firestore `sensor_readings`.
class SensorReadingService {
  static final SensorReadingService instance = SensorReadingService._internal();
  SensorReadingService._internal();

  /// ESP32 device ID used until app hives are linked to sensor devices.
  static const String defaultHiveId = 'HIVE_001';

  /// Fetch the most recent reading for [hiveId]. Returns null if none exist.
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
    } on http.ClientException {
      throw const SensorReadingException('Cannot connect to backend server.');
    } on TimeoutException {
      throw const SensorReadingException('Backend request timed out.');
    } catch (e) {
      developer.log('Failed to fetch latest reading: $e', name: 'SensorReadingService');
      if (e is SensorReadingException) rethrow;
      throw SensorReadingException(e.toString());
    }
  }
}
