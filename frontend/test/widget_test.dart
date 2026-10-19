// Hive Sense smoke test: app boots to splash, then onboarding.
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('App boots and shows Hive Sense onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HiveSenseApp());
    // The splash includes an indeterminate progress indicator, so the whole
    // widget tree never settles. Advance past the splash timer directly.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('Hive Sense'), findsWidgets);
  });
}
