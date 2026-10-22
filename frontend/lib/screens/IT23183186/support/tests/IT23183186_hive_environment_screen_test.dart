import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/models/apiary_model.dart';
import 'package:frontend/services/weather_service.dart';
import 'package:frontend/services/IT23183186_colony_assessment_api.dart';
import 'package:frontend/screens/IT23183186_hive_environment_screen.dart';

class FakeWeather extends WeatherService {
  @override
  Future<WeatherForecast> fetchForecast(String location) async =>
      const WeatherForecast(days: []);
  String? location;
  @override
  Future<WeatherHistoryResponse> fetchHistoryAnalysis(
    String location, {
    int days = 7,
  }) async => throw Exception('History unavailable in fixture');
  bool fail = false;
  @override
  Future<WeatherImpactResponse> fetchImpact(String location) async {
    this.location = location;
    if (fail) throw Exception('offline');
    return WeatherImpactResponse(
      weather: const CurrentWeather(
        locationName: 'Kandy',
        region: 'Central',
        temperatureC: 25,
        humidityPercent: 78,
        feelsLikeC: 26,
        windKph: 6,
        windDirection: 'NE',
        precipitationMm: 0.2,
        uvIndex: 3,
        condition: 'Cloudy',
        iconUrl: null,
        updatedAt: '2026-10-21 13:00',
      ),
      analysis: EnvironmentalImpact.fromJson({
        'season': 'Inter-monsoon',
        'season_period': 'October',
        'environmental_summary': 'Local rainfall may reduce outdoor activity.',
        'recommendations': ['Check the entrance after rain.'],
      }),
    );
  }
}

class FakeAssessment extends ColonyAssessmentApi {
  String? hiveId;
  String? query;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> fetch({String? location, String? hiveId}) async {
    this.hiveId = hiveId;
    query = location;
    if (fail) throw Exception('offline');
    return {
      'assessment': {
        'status': 'inconclusive',
        'alerts': [],
        'missing_inputs': ['Hive sensors'],
        'rules': {},
        'limitations': [],
      },
    };
  }
}

const hive = HiveModel(
  id: 'hive-42',
  userId: 'user',
  apiaryId: 'yard-1',
  name: 'Clover hive',
  boxNumber: 1,
  numFrames: 8,
  createdAt: '',
);
ApiaryModel yard({String? gps = '7.2906,80.6337'}) => ApiaryModel(
  id: 'yard-1',
  userId: 'user',
  locationName: 'Kandy',
  areaAddress: 'Hill garden',
  gpsLocation: gps,
  createdAt: '',
);

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final width in [320.0, 900.0]) {
    testWidgets('saved hive uses its apiary GPS and fits width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final weather = FakeWeather();
      final assessment = FakeAssessment();
      await tester.pumpWidget(
        MaterialApp(
          home: IT23183186HiveEnvironmentScreen(
            hive: hive,
            apiary: yard(),
            weatherService: weather,
            assessmentApi: assessment,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(weather.location, '7.2906,80.6337');
      expect(assessment.query, weather.location);
      expect(assessment.hiveId, 'hive-42');
      expect(find.text('Clover hive'), findsOneWidget);
      expect(find.text('25.0 \u00b0C'), findsOneWidget);
      expect(
        find.textContaining('not a live health assessment'),
        findsOneWidget,
      );
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -650),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('falls back to saved city and recovers from provider failure', (
    tester,
  ) async {
    final weather = FakeWeather()..fail = true;
    final assessment = FakeAssessment()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: IT23183186HiveEnvironmentScreen(
          hive: hive,
          apiary: yard(gps: null),
          weatherService: weather,
          assessmentApi: assessment,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(weather.location, 'Kandy, Sri Lanka');
    expect(
      find.textContaining('Outdoor conditions could not be loaded'),
      findsWidgets,
    );
    weather.fail = false;
    assessment.fail = false;
    await tester.tap(find.byTooltip('Refresh hive environment'));
    await tester.pumpAndSettle();
    expect(find.text('25.0 \u00b0C'), findsOneWidget);
    expect(
      find.textContaining('Outdoor conditions could not be loaded'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
