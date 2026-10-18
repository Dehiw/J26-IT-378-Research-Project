// Hive Sense smoke test: app boots to splash, then onboarding.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';
import 'package:frontend/screens/it23136274_ai_health_assessment_screen.dart';
import 'package:frontend/screens/it23136274_alerts_history_screen.dart';
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

  testWidgets(
    'IT23136274 AI Health Assessment screen renders status, indicators & summary',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: IT23136274AiHealthAssessmentScreen(
            hiveName: 'Hive 01',
            apiaryName: 'Yakkala Apiary',
            initialStatus: 'Early Stress',
            confidence: 0.87,
          ),
        ),
      );
      await tester.pump();

      // Verify header
      expect(find.text('AI Health Assessment'), findsOneWidget);
      expect(find.text('Hive 01 • Yakkala Apiary'), findsOneWidget);

      // Verify colony status card
      expect(find.text('Colony Health Status'), findsOneWidget);
      expect(find.text('Early Stress'), findsOneWidget);
      expect(find.text('Confidence: 87%'), findsOneWidget);

      // Verify detected indicators
      expect(find.text('Detected Indicators'), findsOneWidget);
      expect(find.text('Hive weight is decreasing'), findsOneWidget);
      expect(find.text('Bee activity lower than normal'), findsOneWidget);
      expect(find.text('Humidity higher than usual'), findsOneWidget);

      // Verify recommendation
      expect(find.text('Recommendation'), findsOneWidget);
      expect(
        find.text(
          'Inspect the colony and continue monitoring for the next 24 hours.',
        ),
        findsOneWidget,
      );
      // Verify sensor summary
      expect(find.text('Sensor Summary'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('31.2 °C'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Humidity'), findsOneWidget);
      expect(find.text('75 %'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Hive Weight'), findsOneWidget);
      expect(find.text('12.4 kg'), findsOneWidget);
      expect(find.text('Decreasing'), findsOneWidget);
      expect(find.text('Bee Activity'), findsOneWidget);
      expect(find.text('18/min'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);

      // Verify trends action button
      expect(find.text('View Detailed Sensor Trends'), findsOneWidget);
    },
  );

  testWidgets(
    'IT23136274 Alerts & History screen renders alerts cards and segmented tabs',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: IT23136274AlertsHistoryScreen(
            hiveName: 'Hive 01',
            apiaryName: 'Yakkala Apiary',
          ),
        ),
      );
      await tester.pump();

      // Verify header
      expect(find.text('Alerts & History'), findsOneWidget);
      expect(find.text('Hive 01 • Yakkala Apiary'), findsOneWidget);

      // Verify segmented tabs
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      // Verify 4 alert cards from reference image
      expect(find.text('Hive weight dropped significantly'), findsOneWidget);
      expect(find.text('Today • 10:20 AM'), findsOneWidget);

      expect(find.text('Humidity above normal range'), findsOneWidget);
      expect(find.text('Today • 08:15 AM'), findsOneWidget);

      expect(find.text('Bee activity lower than usual'), findsOneWidget);
      expect(find.text('Yesterday • 4:30 PM'), findsOneWidget);

      expect(find.text('Conditions returned to normal'), findsOneWidget);
      expect(find.text('Yesterday • 6:00 PM'), findsOneWidget);

      // Switch to History tab
      await tester.tap(find.text('History'));
      await tester.pump();

      expect(find.text('Recent Event Logs'), findsOneWidget);
      expect(find.text('Microclimate Stabilization'), findsOneWidget);
    },
  );
}
