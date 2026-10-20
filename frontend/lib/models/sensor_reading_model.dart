/// ESP32 sensor reading for a hive (Firestore `sensor_readings`).
/// Sensor fields are nullable so a document with a missing field never crashes the UI.
class SensorReading {
  final String id;
  final String hiveId;
  final double? temperature; // °C
  final double? humidity; // %
  final double? weight; // kg
  final DateTime? timestamp; // local time

  const SensorReading({
    required this.id,
    required this.hiveId,
    this.temperature,
    this.humidity,
    this.weight,
    this.timestamp,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];
    return SensorReading(
      id: json['id']?.toString() ?? '',
      hiveId: json['hive_id']?.toString() ?? '',
      temperature: _toDouble(json['temperature']),
      humidity: _toDouble(json['humidity']),
      weight: _toDouble(json['weight']),
      timestamp: rawTimestamp is String ? DateTime.tryParse(rawTimestamp)?.toLocal() : null,
    );
  }

  static double? _toDouble(Object? value) => value is num ? value.toDouble() : null;
}
