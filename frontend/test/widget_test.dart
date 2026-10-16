// Hive Sense smoke test: app boots to splash, then onboarding.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';
import 'package:frontend/screens/it23136274_sensor_trends_screen.dart';

void main() {
  testWidgets('App boots and shows Hive Sense onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HiveSenseApp());
    await tester.pumpAndSettle();

    expect(find.text('Hive Sense'), findsWidgets);
  });

  testWidgets('IT23136274 Sensor Trends screen renders graphs and metrics', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IT23136274SensorTrendsScreen(
          hiveName: 'Hive 01',
          apiaryName: 'Yakkala Apiary',
        ),
      ),
    );
    await tester.pump();

    // Verify header elements
    expect(find.text('Temperature'), findsWidgets);
    expect(find.text('Hive 01 • Yakkala Apiary'), findsOneWidget);

    // Verify time range filters
    expect(find.text('24H'), findsOneWidget);
    expect(find.text('7D'), findsOneWidget);
    expect(find.text('30D'), findsOneWidget);

    // Verify statistics and insights cards
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Average'), findsOneWidget);
    expect(find.text('Min'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
  });
}
