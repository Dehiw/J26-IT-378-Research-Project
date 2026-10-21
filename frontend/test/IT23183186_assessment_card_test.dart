import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/IT23183186_assessment_card.dart';

void main() {
  testWidgets(
    'compact dashboard summary fits a narrow screen and hides technical detail',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ColonyAssessmentCard(
                compact: true,
                assessment: {
                  'status': 'inconclusive',
                  'alerts': [],
                  'missing_inputs': [
                    'Weather',
                    'Hive sensors',
                    'Image inference',
                  ],
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('More evidence needed'), findsOneWidget);
      expect(find.text('3 missing inputs'), findsOneWidget);
      expect(find.text('Rules and limitations'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'shows alert provenance and missing evidence without a numeric disease score',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ColonyAssessmentCard(
                assessment: {
                  'status': 'preliminary',
                  'summary': 'Available evidence does not establish colony disease risk.',
                  'environmental_risk': 'high',
                  'disease_risk': 'inconclusive',
                  'generated_at': '2026-10-20T10:00:00Z',
                  'alerts': [
                    {
                      'id': 'outdoor_temperature',
                      'severity': 'high',
                      'source': 'WeatherAPI',
                      'message': 'Outdoor temperature requires inspection.',
                    },
                  ],
                  'missing_inputs': ['Fresh hive sensor readings'],
                  'rules': {},
                  'limitations': [],
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('Environmental watch: high'), findsOneWidget);
      expect(find.text('Disease indicators: inconclusive'), findsOneWidget);
      expect(find.text('high · WeatherAPI'), findsOneWidget);
      expect(find.textContaining('Fresh hive sensor readings'), findsOneWidget);
      expect(find.textContaining('/ 100'), findsNothing);
    },
  );
}
