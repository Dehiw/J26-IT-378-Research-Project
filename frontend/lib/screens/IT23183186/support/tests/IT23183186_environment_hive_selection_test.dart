import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/services/environment_fallback.dart';
import 'package:frontend/screens/IT23183186_disease_risk_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/models/apiary_model.dart';
import 'package:frontend/services/apiary_service.dart';
import 'package:frontend/screens/IT23183186_environment_dashboard_screen.dart';

import 'IT23183186_hive_environment_screen_test.dart'
    show FakeWeather, FakeAssessment;

ApiaryModel apiary(String id, String name, String gps) => ApiaryModel(
  id: id,
  userId: 'user',
  locationName: name,
  areaAddress: name,
  gpsLocation: gps,
  createdAt: '',
);
HiveModel hive(String id, String yard, String name) => HiveModel(
  id: id,
  userId: 'user',
  apiaryId: yard,
  name: name,
  boxNumber: 1,
  numFrames: 8,
  createdAt: '',
);

class FakeApiaries implements ApiaryService {
  final yards = [
    apiary('a', 'Kandy garden', '7.29,80.63'),
    apiary('b', 'Galle garden', '6.03,80.21'),
  ];
  final requested = <String>[];
  bool fail = false;
  @override
  ApiaryModel? selectedApiary;
  @override
  Future<List<ApiaryModel>> fetchApiaries() async {
    if (fail) throw Exception('offline');
    selectedApiary ??= yards.first;
    return yards;
  }

  @override
  Future<void> selectApiary(ApiaryModel apiary) async {
    selectedApiary = apiary;
  }

  @override
  Future<List<HiveModel>> fetchHives(String apiaryId) async {
    requested.add(apiaryId);
    return apiaryId == 'a'
        ? [hive('h1', 'a', 'Clover hive'), hive('h2', 'a', 'Orchard hive')]
        : [hive('h3', 'b', 'Coastal hive')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('database selections update hive monitoring and apiary weather', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeApiaries();
    final weather = FakeWeather();
    final assessment = FakeAssessment();
    await tester.pumpWidget(
      MaterialApp(
        home: EnvironmentDashboardScreen(
          apiaryService: service,
          weatherService: weather,
          assessmentApi: assessment,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final selectors = find.byType(DropdownButtonFormField<String>);
    expect(
      tester.getTopLeft(selectors.last).dy,
      greaterThan(tester.getBottomLeft(selectors.first).dy),
    );
    expect(find.text('Daily & hourly forecast'), findsNothing);
    expect(find.text('Monthly calendar'), findsNothing);
    expect(service.requested, ['a']);
    expect(weather.location, '7.29,80.63');
    expect(assessment.hiveId, 'h1');
    await tester.tap(find.text('Change location'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Matara');
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(weather.location, 'Matara');
    expect(service.selectedApiary?.id, 'a');
    expect(find.text('Use saved apiary'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orchard hive').last);
    await tester.pumpAndSettle();
    expect(assessment.hiveId, 'h2');
    expect(weather.location, 'Matara');
    await tester.ensureVisible(
      find.byTooltip('Reload saved apiaries and hives'),
    );
    await tester.tap(find.byTooltip('Reload saved apiaries and hives'));
    await tester.pumpAndSettle();
    expect(assessment.hiveId, 'h2');
    expect(weather.location, 'Matara');
    await tester.ensureVisible(find.text('Use saved apiary'));
    await tester.tap(find.text('Use saved apiary'));
    await tester.pumpAndSettle();
    expect(weather.location, '7.29,80.63');
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galle garden').last);
    await tester.pumpAndSettle();
    expect(service.requested, ['a', 'a', 'b']);
    expect(weather.location, '6.03,80.21');
    expect(assessment.hiveId, 'h3');
    expect(find.text('Coastal hive'), findsOneWidget);
    expect(find.text('Orchard hive'), findsNothing);
    expect(tester.takeException(), isNull);
    final more = find.text('View more about environment');
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Environment details'), findsOneWidget);
    expect(find.text('Daily & hourly forecast'), findsOneWidget);
    expect(find.text('Weather details'), findsOneWidget);
    expect(find.text('Monthly calendar'), findsOneWidget);
    expect(find.text('Weather overview'), findsOneWidget);
    expect(find.text('Weather trends'), findsOneWidget);
    expect(find.text('Weather at your apiary'), findsNothing);
    expect(weather.location, '6.03,80.21');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'monitoring route restores a demo hive without shared real selection',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      EnvironmentFallback.instance.clearSession();
      await tester.runAsync(
        () => EnvironmentFallback.instance.fixture('hives'),
      );
      final assessment = FakeAssessment();
      await tester.pumpWidget(
        MaterialApp(
          home: DiseaseRiskScreen(
            hiveId: 'demo-hive-1',
            location: 'Kandy',
            assessmentApi: assessment,
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(assessment.hiveId, 'demo-hive-1');
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.initialValue, 'demo-hive-1');
      expect(ApiaryService.instance.selectedApiary, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      EnvironmentFallback.instance.clearSession();
    },
  );
}
