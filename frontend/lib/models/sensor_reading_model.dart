/// Latest ESP32 sensor reading for a hive (Firestore `sensor_readings`).
class SensorReading {
  final String id;
  final String hiveId;
  final double temperature; // °C
  final double humidity; // %
  final double weight; // kg
  final DateTime? timestamp; // local time

  const SensorReading({
    required this.id,
    required this.hiveId,
    required this.temperature,
    required this.humidity,
    required this.weight,
    this.timestamp,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'] as String?;
    return SensorReading(
      id: json['id'] as String? ?? '',
      hiveId: json['hive_id'] as String? ?? '',
      temperature: (json['temperature'] as num? ?? 0).toDouble(),
      humidity: (json['humidity'] as num? ?? 0).toDouble(),
      weight: (json['weight'] as num? ?? 0).toDouble(),
      timestamp: rawTimestamp != null ? DateTime.tryParse(rawTimestamp)?.toLocal() : null,
    );
  }
}
