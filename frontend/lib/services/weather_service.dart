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

class HistoricalWeatherDay {
  final String date;
  final double averageTemperatureC;
  final double minimumTemperatureC;
  final double maximumTemperatureC;
  final double averageHumidityPercent;
  final double precipitationMm;

  const HistoricalWeatherDay({
    required this.date,
    required this.averageTemperatureC,
    required this.minimumTemperatureC,
    required this.maximumTemperatureC,
    required this.averageHumidityPercent,
    required this.precipitationMm,
  });

  factory HistoricalWeatherDay.fromJson(Map<String, dynamic> json) =>
      HistoricalWeatherDay(
        date: json['date'] as String,
        averageTemperatureC: (json['average_temperature_c'] as num).toDouble(),
        minimumTemperatureC: (json['min_temperature_c'] as num).toDouble(),
        maximumTemperatureC: (json['max_temperature_c'] as num).toDouble(),
        averageHumidityPercent: (json['average_humidity_percent'] as num)
            .toDouble(),
        precipitationMm: (json['precipitation_mm'] as num).toDouble(),
      );
}

class EnvironmentalImpact {
  final String season;
  final String seasonPeriod;
  final String regionalContext;
  final String environmentalSummary;
  final Map<String, dynamic> beeActivity;
  final Map<String, dynamic> colonyGrowth;
  final Map<String, dynamic> foodAvailability;
  final Map<String, dynamic> population;
  final Map<String, dynamic> developmentSuitability;
  final List<String> recommendations;
  final Map<String, dynamic> dataQuality;

  const EnvironmentalImpact({
    required this.season,
    required this.seasonPeriod,
    required this.regionalContext,
    required this.environmentalSummary,
    required this.beeActivity,
    required this.colonyGrowth,
    required this.foodAvailability,
    this.population = const {},
    this.developmentSuitability = const {},
    required this.recommendations,
    required this.dataQuality,
  });

  factory EnvironmentalImpact.fromJson(
    Map<String, dynamic> json,
  ) => EnvironmentalImpact(
    season: json['season'] as String? ?? 'Season unavailable',
    seasonPeriod: json['season_period'] as String? ?? '',
    regionalContext: json['regional_context'] as String? ?? '',
    environmentalSummary: json['environmental_summary'] as String? ?? '',
    beeActivity: json['bee_activity'] as Map<String, dynamic>? ?? const {},
    colonyGrowth: json['colony_growth'] as Map<String, dynamic>? ?? const {},
    foodAvailability:
        json['food_availability'] as Map<String, dynamic>? ?? const {},
    population: json['population'] as Map<String, dynamic>? ?? const {},
    developmentSuitability:
        json['development_suitability'] as Map<String, dynamic>? ?? const {},
    recommendations: (json['recommendations'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    dataQuality: json['data_quality'] as Map<String, dynamic>? ?? const {},
  );
}

class WeatherImpactResponse {
  final CurrentWeather weather;
  final EnvironmentalImpact analysis;

  const WeatherImpactResponse({required this.weather, required this.analysis});

  factory WeatherImpactResponse.fromJson(Map<String, dynamic> json) =>
      WeatherImpactResponse(
        weather: CurrentWeather.fromJson(
          json['weather'] as Map<String, dynamic>,
        ),
        analysis: EnvironmentalImpact.fromJson(
          json['analysis'] as Map<String, dynamic>,
        ),
      );
}

class WeatherHistoryResponse {
  final List<HistoricalWeatherDay> days;
  final Map<String, dynamic> analysis;
  const WeatherHistoryResponse({required this.days, required this.analysis});
}

class WeatherService {
  const WeatherService();

  Future<WeatherImpactResponse> fetchImpact(String location) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/environment/impact')
        .replace(queryParameters: {'q': location});
    final response = await http.get(uri).timeout(const Duration(seconds: 18));
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail =
          payload['detail']?.toString() ?? 'Environmental analysis failed.';
      throw WeatherException(detail);
    }
    return WeatherImpactResponse.fromJson(payload);
  }

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

  Future<List<HistoricalWeatherDay>> fetchHistory(
    String location, {
    int days = 7,
  }) async => (await fetchHistoryAnalysis(location, days: days)).days;

  Future<WeatherHistoryResponse> fetchHistoryAnalysis(
    String location, {
    int days = 7,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/environment/weather/history')
        .replace(queryParameters: {'q': location, 'days': '$days'});
    final response = await http.get(uri).timeout(const Duration(seconds: 35));
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail =
          payload['detail']?.toString() ?? 'Weather history lookup failed.';
      throw WeatherException(detail);
    }
    final records = payload['days'] as List<dynamic>? ?? const [];
    final recordsList = records
        .map(
          (record) =>
              HistoricalWeatherDay.fromJson(record as Map<String, dynamic>),
        )
        .toList(growable: false);
    return WeatherHistoryResponse(
      days: recordsList,
      analysis: payload['analysis'] as Map<String, dynamic>? ?? const {},
    );
  }
}

class WeatherException implements Exception {
  final String message;
  const WeatherException(this.message);
  @override
  String toString() => message;
}
