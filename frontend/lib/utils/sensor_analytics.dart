import 'package:intl/intl.dart';

import '../models/sensor_reading_model.dart';

/// "30.5 °C" / "-- °C" when the value is missing. [pattern] is an intl NumberFormat pattern.
String formatSensorValue(double? value, String unit, {String pattern = '0.#'}) =>
    value == null ? '-- $unit' : '${NumberFormat(pattern).format(value)} $unit';

/// "1:53 AM" for today, "Oct 18, 1:53 AM" for older readings.
String formatReadingTime(DateTime timestamp) {
  final now = DateTime.now();
  final isToday =
      timestamp.year == now.year && timestamp.month == now.month && timestamp.day == now.day;
  return isToday
      ? DateFormat.jm().format(timestamp)
      : DateFormat('MMM d, h:mm a').format(timestamp);
}

/// Statistics over sensor readings.
class SensorStats {
  SensorStats._();

  static double? average(Iterable<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double? min(Iterable<double> values) =>
      values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);

  static double? max(Iterable<double> values) =>
      values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);
}

enum WeightTrend { increasing, decreasing, stable, insufficientData }

extension WeightTrendLabel on WeightTrend {
  String get label {
    switch (this) {
      case WeightTrend.increasing:
        return 'Increasing';
      case WeightTrend.decreasing:
        return 'Decreasing';
      case WeightTrend.stable:
        return 'Stable';
      case WeightTrend.insufficientData:
        return 'Not enough data';
    }
  }
}

/// Weight trend from multiple readings (never from a single reading).
///
/// Fits a least-squares line through (time, weight) for the given readings and
/// converts the slope into the net change over the covered time span.
/// A change smaller than [minChangeKg] (load-cell noise) is reported as stable.
WeightTrend calculateWeightTrend(
  List<SensorReading> readings, {
  int minReadings = 3,
  Duration minSpan = const Duration(minutes: 30),
  double minChangeKg = 0.05,
}) {
  final points = readings
      .where((r) => r.weight != null && r.timestamp != null)
      .map((r) => (t: r.timestamp!.millisecondsSinceEpoch / 3600000.0, w: r.weight!))
      .toList();
  if (points.length < minReadings) return WeightTrend.insufficientData;

  final firstT = points.map((p) => p.t).reduce((a, b) => a < b ? a : b);
  final lastT = points.map((p) => p.t).reduce((a, b) => a > b ? a : b);
  final spanHours = lastT - firstT;
  if (spanHours * 60 < minSpan.inMinutes) return WeightTrend.insufficientData;

  final meanT = points.map((p) => p.t).reduce((a, b) => a + b) / points.length;
  final meanW = points.map((p) => p.w).reduce((a, b) => a + b) / points.length;
  var num = 0.0, den = 0.0;
  for (final p in points) {
    num += (p.t - meanT) * (p.w - meanW);
    den += (p.t - meanT) * (p.t - meanT);
  }
  if (den == 0) return WeightTrend.insufficientData;

  final netChangeKg = (num / den) * spanHours;
  if (netChangeKg.abs() < minChangeKg) return WeightTrend.stable;
  return netChangeKg > 0 ? WeightTrend.increasing : WeightTrend.decreasing;
}

enum SensorDisplayStatus { low, normal, high, unknown }

extension SensorDisplayStatusLabel on SensorDisplayStatus {
  String get label {
    switch (this) {
      case SensorDisplayStatus.low:
        return 'Low';
      case SensorDisplayStatus.normal:
        return 'Normal';
      case SensorDisplayStatus.high:
        return 'High';
      case SensorDisplayStatus.unknown:
        return 'No data';
    }
  }

  bool get isWarning => this == SensorDisplayStatus.low || this == SensorDisplayStatus.high;
}

/// DISPLAY-ONLY threshold rules for status badges.
/// These are simple UI ranges, not the colony health AI model; replace them
/// with the trained ML model output when it is available.
class SensorDisplayRules {
  SensorDisplayRules._();

  static const double tempMin = 30; // °C
  static const double tempMax = 36; // °C
  static const double humidityMin = 55; // %
  static const double humidityMax = 80; // %

  static SensorDisplayStatus temperatureStatus(double? celsius) =>
      _rangeStatus(celsius, tempMin, tempMax);

  static SensorDisplayStatus humidityStatus(double? percent) =>
      _rangeStatus(percent, humidityMin, humidityMax);

  static SensorDisplayStatus _rangeStatus(double? value, double min, double max) {
    if (value == null) return SensorDisplayStatus.unknown;
    if (value < min) return SensorDisplayStatus.low;
    if (value > max) return SensorDisplayStatus.high;
    return SensorDisplayStatus.normal;
  }

  /// Indicator sentences derived from the display rules above.
  static List<String> indicators({
    required SensorDisplayStatus temperature,
    required SensorDisplayStatus humidity,
    required WeightTrend weightTrend,
  }) {
    return [
      if (weightTrend == WeightTrend.decreasing) 'Hive weight is decreasing',
      if (temperature == SensorDisplayStatus.high) 'Temperature higher than normal',
      if (temperature == SensorDisplayStatus.low) 'Temperature lower than normal',
      if (humidity == SensorDisplayStatus.high) 'Humidity higher than usual',
      if (humidity == SensorDisplayStatus.low) 'Humidity lower than usual',
    ];
  }
}
