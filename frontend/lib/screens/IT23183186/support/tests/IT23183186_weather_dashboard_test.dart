import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/widgets/IT23183186_weather_dashboard.dart';
import 'package:frontend/widgets/IT23183186_apiary_map.dart';
import 'package:frontend/services/weather_service.dart';
import 'package:frontend/utils/theme.dart';

const current = CurrentWeather(
  locationName: 'Kandy',
  region: 'Central',
  latitude: 7.29,
  longitude: 80.63,
  temperatureC: 28,
  humidityPercent: 78,
  feelsLikeC: 31,
  windKph: 6,
  windDirection: 'NE',
  precipitationMm: 0.2,
  uvIndex: 4,
  condition: 'Mostly cloudy',
  iconUrl: null,
  updatedAt: '2026-10-21 15:00',
  cloudPercent: 77,
  visibilityKm: 10,
  gustKph: 12,
  pressureMb: 1010,
);
final forecast = WeatherForecast(
  localtime: '2026-10-21 15:00',
  days: [
    for (var day = 21; day <= 23; day++)
      {
        'date': '2026-10-$day',
        'day': {
          'maxtemp_c': 30,
          'mintemp_c': 23,
          'totalprecip_mm': 2,
          'daily_chance_of_rain': 60,
          'condition': {'text': 'Light rain'},
        },
        'hour': [
          for (var h = 0; h < 24; h++)
            {
              'time': '2026-10-$day ${h.toString().padLeft(2, '0')}:00',
              'temp_c': 25 + h % 5,
              'feelslike_c': 27 + h % 5,
              'humidity': 70,
              'precip_mm': 0.2,
              'wind_kph': 6,
              'condition': {'text': 'Cloudy'},
            },
        ],
      },
  ],
);
final history = [
  for (var d = 14; d <= 20; d++)
    HistoricalWeatherDay(
      date: '2026-10-$d',
      averageTemperatureC: 27,
      minimumTemperatureC: 23,
      maximumTemperatureC: 30,
      averageHumidityPercent: 78,
      precipitationMm: d % 2 == 0 ? 1 : 0,
      maximumWindKph: 12,
    ),
];

Widget board() => EnvironmentWeatherDashboard(
  weather: current,
  forecast: forecast,
  history: history,
  locationQuery: '7.29,80.63',
  onRetry: () {},
);

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final width in [320.0, 1120.0]) {
    testWidgets('weather components fit $width and keep true map coordinates', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RepaintBoundary(
            key: const ValueKey('weather-preview'),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: board(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('WEATHER_PREVIEW') && width == 1120) {
        await tester.runAsync(() async {
          await GoogleFonts.pendingFonts();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('weather-preview')),
          );
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build').create(recursive: true);
          await File('build/IT23183186_weather_preview.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      final map = tester.widget<ApiaryWeatherMap>(
        find.byType(ApiaryWeatherMap),
      );
      expect(map.latitude, 7.29);
      expect(map.longitude, 80.63);
      expect(find.text('CURRENT WEATHER'), findsOneWidget);
      expect(find.text('Air quality'), findsOneWidget);
      expect(find.textContaining('not numeric AQI'), findsOneWidget);
      await tester.ensureVisible(find.text('Show list'));
      await tester.tap(find.text('Show list'));
      await tester.pumpAndSettle();
      expect(find.text('Show chart'), findsOneWidget);
      await tester.ensureVisible(find.text('Monthly calendar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Weather trends'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('calendar leaves dates outside real provider coverage empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: board())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Jan'));
    await tester.tap(find.text('Jan'));
    await tester.pumpAndSettle();
    expect(find.text('No observations loaded for this month.'), findsOneWidget);
    await tester.ensureVisible(find.text('1').first);
    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    expect(find.text('No weather data loaded for this date.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing weather does not invent coordinates or values', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EnvironmentWeatherDashboard(
              locationQuery: 'Kandy',
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ApiaryWeatherMap), findsNothing);
    expect(find.text('Weather is unavailable'), findsOneWidget);
    expect(find.text('No forecast data is available.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
