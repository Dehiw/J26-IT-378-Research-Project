import 'package:http/http.dart' as http;

import '../utils/api_config.dart';
import 'environment_fallback.dart';

class CurrentWeather {
  final String source;
  final double? latitude,
      longitude,
      cloudPercent,
      visibilityKm,
      pressureMb,
      dewPointC,
      gustKph,
      windDegree;
  final Map<String, dynamic>? airQuality;
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
    this.source = 'live',
    this.latitude,
    this.longitude,
    this.cloudPercent,
    this.visibilityKm,
    this.pressureMb,
    this.dewPointC,
    this.gustKph,
    this.windDegree,
    this.airQuality,
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
      source: dataSource(json),
      latitude: (location['latitude'] as num?)?.toDouble(),
      longitude: (location['longitude'] as num?)?.toDouble(),
      cloudPercent: (current['cloud_percent'] as num?)?.toDouble(),
      visibilityKm: (current['visibility_km'] as num?)?.toDouble(),
      pressureMb: (current['pressure_mb'] as num?)?.toDouble(),
      dewPointC: (current['dew_point_c'] as num?)?.toDouble(),
      gustKph: (current['gust_kph'] as num?)?.toDouble(),
      windDegree: (current['wind_degree'] as num?)?.toDouble(),
      airQuality: current['air_quality'] as Map<String, dynamic>?,
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
      iconUrl: icon == null
          ? null
          : (icon.startsWith('//') ? 'https:$icon' : icon),
      updatedAt: current['last_updated'] as String? ?? '',
    );
  }
}

class HistoricalWeatherDay {
  final String source;
  final double? maximumWindKph;
  final String date;
  final double averageTemperatureC;
  final double minimumTemperatureC;
  final double maximumTemperatureC;
  final double averageHumidityPercent;
  final double precipitationMm;

  const HistoricalWeatherDay({
    this.source = 'live',
    this.maximumWindKph,
    required this.date,
    required this.averageTemperatureC,
    required this.minimumTemperatureC,
    required this.maximumTemperatureC,
    required this.averageHumidityPercent,
    required this.precipitationMm,
  });

  factory HistoricalWeatherDay.fromJson(Map<String, dynamic> json) =>
      HistoricalWeatherDay(
        source: dataSource(json),
        maximumWindKph: (json['maximum_wind_kph'] as num?)?.toDouble(),
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
  final String source;
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
    this.source = 'live',
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
    source: dataSource(json),
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
  final String source;
  final List<HistoricalWeatherDay> days;
  final Map<String, dynamic> analysis;
  const WeatherHistoryResponse({
    required this.days,
    required this.analysis,
    this.source = 'live',
  });
}

class WeatherService {
  final http.Client? client;
  const WeatherService({this.client});
  Future<Map<String, dynamic>> _read(
    String path,
    String location,
    String fixture, {
    int? days,
  }) => EnvironmentFallback.instance.request(
    'weather/$path/$location/${days ?? ''}',
    Uri.parse('${ApiConfig.baseUrl}/environment/$path').replace(
      queryParameters: {'q': location, if (days != null) 'days': '$days'},
    ),
    fixture,
    client: client,
  );
  Future<WeatherForecast> fetchForecast(String location) async =>
      WeatherForecast.fromJson(await _read('forecast', location, 'forecast'));
  Future<WeatherImpactResponse> fetchImpact(String location) async =>
      WeatherImpactResponse.fromJson(await _read('impact', location, 'impact'));
  Future<CurrentWeather> fetchCurrent(String location) async =>
      CurrentWeather.fromJson(await _read('weather', location, 'weather'));
  Future<List<HistoricalWeatherDay>> fetchHistory(
    String location, {
    int days = 7,
  }) async => (await fetchHistoryAnalysis(location, days: days)).days;
  Future<WeatherHistoryResponse> fetchHistoryAnalysis(
    String location, {
    int days = 7,
  }) async {
    final payload = await _read(
      'weather/history',
      location,
      'weather_history',
      days: days,
    );
    return WeatherHistoryResponse(
      days: (payload['days'] as List? ?? [])
          .map(
            (r) => HistoricalWeatherDay.fromJson(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList(),
      analysis: Map<String, dynamic>.from(payload['analysis'] as Map? ?? {}),
      source: dataSource(payload),
    );
  }
}

class WeatherException implements Exception {
  final String message;
  const WeatherException(this.message);
  @override
  String toString() => message;
}

class WeatherForecast {
  final String source;
  final List<Map<String, dynamic>> days;
  final String? localtime;
  const WeatherForecast({
    this.source = 'live',
    required this.days,
    this.localtime,
  });
  factory WeatherForecast.fromJson(Map<String, dynamic> json) =>
      WeatherForecast(
        source: dataSource(json),
        days: (json['days'] as List? ?? [])
            .map((d) => Map<String, dynamic>.from(d as Map))
            .toList(),
        localtime: (json['location'] as Map?)?['localtime'] as String?,
      );
}
