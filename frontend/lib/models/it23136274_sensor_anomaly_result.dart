/// IT23136274 - Result of the experimental Isolation Forest V2 sensor anomaly model
/// (`GET /colony-health/sensor-anomaly/latest/{hive_id}`).
///
/// This flags unusual temperature/humidity patterns only. It is not a colony
/// health diagnosis, and the backend returns no confidence or probability.
class SensorAnomalyResult {
  static const String normalStatus = 'Normal Sensor Pattern';
  static const String inspectionStatus = 'Inspection Recommended';

  final String hiveId;
  final String readingId;
  final double temperature; // °C
  final double humidity; // %
  final DateTime? timestamp; // local time of the reading the model used
  final int modelPrediction; // 1 = normal pattern, -1 = anomalous pattern
  final String status;
  final String recommendation;
  final String model;
  final String note;

  const SensorAnomalyResult({
    required this.hiveId,
    required this.readingId,
    required this.temperature,
    required this.humidity,
    required this.timestamp,
    required this.modelPrediction,
    required this.status,
    required this.recommendation,
    required this.model,
    required this.note,
  });

  bool get inspectionRecommended => modelPrediction == -1;

  factory SensorAnomalyResult.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];
    return SensorAnomalyResult(
      hiveId: json['hive_id']?.toString() ?? '',
      readingId: json['reading_id']?.toString() ?? '',
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      timestamp: rawTimestamp is String ? DateTime.tryParse(rawTimestamp)?.toLocal() : null,
      modelPrediction: (json['model_prediction'] as num).toInt(),
      status: json['status']?.toString() ?? '',
      recommendation: json['recommendation']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }
}
