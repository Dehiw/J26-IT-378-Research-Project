import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/api_config.dart';

class CurrentWeather {
  final String locationName;
  final String? region;
  final double temperatureC;
  final int humidityPercent;
  final double feelsLikeC;
  final double windKph;
  final String windDirection;
  final double precipitationMm;
  final double uvIndex;
  final String condition;
  final String? iconUrl;
  final String updatedAt;

  const CurrentWeather({
    required this.locationName,
    required this.region,
    required this.temperatureC,
    required this.humidityPercent,
    required this.feelsLikeC,
    required this.windKph,
    required this.windDirection,
    required this.precipitationMm,
    required this.uvIndex,
    required this.condition,
    required this.iconUrl,
    required this.updatedAt,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;
    final icon = current['icon'] as String?;
    return CurrentWeather(
      locationName: location['name'] as String? ?? 'Unknown location',
      region: location['region'] as String?,
      temperatureC: (current['temperature_c'] as num).toDouble(),
      humidityPercent: (current['humidity_percent'] as num).toInt(),
      feelsLikeC: (current['feels_like_c'] as num).toDouble(),
      windKph: (current['wind_kph'] as num).toDouble(),
      windDirection: current['wind_direction'] as String? ?? '',
      precipitationMm: (current['precipitation_mm'] as num).toDouble(),
      uvIndex: (current['uv_index'] as num).toDouble(),
      condition: current['condition'] as String? ?? 'Current conditions',
      iconUrl: icon == null ? null : 'https:$icon',
      updatedAt: current['last_updated'] as String? ?? '',
    );
  }
}

class WeatherService {
  const WeatherService();

  Future<CurrentWeather> fetchCurrent(String location) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/environment/weather')
        .replace(queryParameters: {'q': location});
    final response = await http.get(uri).timeout(const Duration(seconds: 18));
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = payload['detail']?.toString() ?? 'Weather lookup failed.';
      throw WeatherException(detail);
    }
    return CurrentWeather.fromJson(payload);
  }
}

class WeatherException implements Exception {
  final String message;
  const WeatherException(this.message);
  @override
  String toString() => message;
}
