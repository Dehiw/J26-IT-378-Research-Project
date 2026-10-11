// Hive Sense smoke test: app boots to splash, then onboarding.
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('App boots and shows Hive Sense onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HiveSenseApp());
    await tester.pumpAndSettle();

    expect(find.text('Hive Sense'), findsWidgets);
  });
}
