import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/models/apiary_model.dart';
import 'package:frontend/screens/add_hive_screen.dart';

import 'IT23183186_environment_hive_selection_test.dart' show FakeApiaries;

class SavingApiaries extends FakeApiaries {
  String? createdAtApiary;
  @override
  Future<String> getNextHiveSuggestion(String apiaryId) async =>
      'Hive at $apiaryId';
  @override
  Future<HiveModel> createHive({
    required String apiaryId,
    required String hiveName,
    required int numFrames,
    required String hiveType,
    required String beeSpecies,
    String? installationDate,
  }) async {
    createdAtApiary = apiaryId;
    return HiveModel(
      id: 'new-hive',
      userId: 'user',
      apiaryId: apiaryId,
      name: hiveName,
      boxNumber: 2,
      numFrames: numFrames,
      hiveType: hiveType,
      beeSpecies: beeSpecies,
      createdAt: '',
    );
  }
}

void main() {
  testWidgets('Add Hive saves to chosen database apiary and returns new hive', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final apiaries = SavingApiaries();
    HiveModel? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<HiveModel>(
                  MaterialPageRoute(
                    builder: (_) => AddHiveScreen(
                      apiary: apiaries.yards.first,
                      apiaryService: apiaries,
                    ),
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galle garden').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Hive'));
    await tester.pumpAndSettle();
    expect(apiaries.createdAtApiary, 'b');
    expect(saved?.apiaryId, 'b');
    expect(saved?.name, 'Hive at b');
    expect(tester.takeException(), isNull);
  });
}
