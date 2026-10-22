import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/weather_service.dart';
import 'package:frontend/widgets/IT23183186_season_activity.dart';
import 'package:frontend/screens/IT23183186_seasonal_changes_screen.dart';

final impact = EnvironmentalImpact.fromJson({
  'season': 'Second Inter-monsoon',
  'season_period': 'October-November',
  'regional_context': 'Broad central/intermediate location estimate.',
  'environmental_summary': 'Outdoor weather does not establish colony health.',
  'bee_activity': {
    'assessment': 'Rain may interrupt flight',
    'reason': 'Compare with local observations.',
  },
  'population': {'assessment': 'Not measured'},
  'recommendations': ['Observe flight activity', 'Check local flowering'],
});

void main() {
  for (final width in [320.0, 1120.0]) {
    testWidgets(
      'season panel and detail route fit $width with honest missing data',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: SeasonActivityPanel(
                    impact: impact,
                    onViewMore: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => IT23183186SeasonalChangesScreen(
                          impact: impact,
                          location: 'Kandy',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Second Inter-monsoon'), findsOneWidget);
        expect(find.text('Unavailable'), findsNWidgets(4));
        expect(find.text('Not measured'), findsOneWidget);
        final button = find.text('View more about seasonal changes');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('Seasonal changes'), findsOneWidget);
        expect(find.text('The four rainfall seasons'), findsOneWidget);
        expect(
          find.textContaining(
            'Station monthly climate baseline: not connected.',
          ),
          findsOneWidget,
        );
        expect(find.text('https://doa.gov.lk/bee-keeping/'), findsOneWidget);
        await tester.ensureVisible(find.text('Official Sri Lankan references'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
