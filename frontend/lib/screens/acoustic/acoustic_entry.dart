import 'package:flutter/material.dart';

import 'package:frontend/models/acoustic/hive_option.dart';
import 'package:frontend/screens/acoustic/acoustic_flows.dart';
import 'package:frontend/screens/acoustic/hive_sound_monitor_screen.dart';
import 'package:frontend/services/acoustic/acoustic_service.dart';
import 'package:frontend/services/acoustic/file_picker_audio_picker.dart';
import 'package:frontend/services/acoustic/mock_acoustic_service.dart';
import 'package:frontend/services/apiary_service.dart';
import 'package:frontend/services/inference_service.dart';
import 'package:frontend/screens/IT23183186_environment_dashboard_screen.dart';
import 'package:frontend/screens/IT23185302_relocation_assessment_screen.dart';
import 'package:frontend/screens/health_screen.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/widgets/main_bottom_nav.dart';

/// The service the app uses. This is the one line to change when the real
/// backend service exists. Tests may replace it.
AcousticService acousticService = MockAcousticService(
  hivesProvider: apiaryHivesProvider,
);

/// Opens Hive Sound Monitor. [hiveId] selects that hive; when null, the
/// first hive is selected. [inferenceService] is handed on to the Health and
/// Environment tabs of the bottom bar. Completes when the user leaves the
/// Monitor.
Future<void> openSoundMonitor(
  BuildContext context, {
  String? hiveId,
  InferenceService? inferenceService,
}) {
  final navigator = Navigator.of(context);
  final service = acousticService;
  return navigator.push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AcousticFlows.monitorRouteName),
      builder: (_) => HiveSoundMonitorScreen(
        service: service,
        initialHiveId: hiveId,
        bottomNavigationBar: Builder(
          builder: (context) => MainBottomNav(
            currentIndex: _acousticTab,
            onTap: (index) => _onNavTapped(context, index, inferenceService),
          ),
        ),
        filePicker: const FilePickerAudioPicker(),
        onRecordPressed: (id) => AcousticFlows.startRecording(
          navigator: navigator,
          service: service,
          hiveId: id,
        ),
        onAudioPicked: (id, audio) => AcousticFlows.analyzeUpload(
          navigator: navigator,
          service: service,
          hiveId: id,
          audio: audio,
        ),
      ),
    ),
  );
}

const int _acousticTab = 3;

/// Same destinations as the bottom bar on the team's screens. The Monitor is
/// the Acoustic tab, so tapping it again does nothing.
void _onNavTapped(
  BuildContext context,
  int index,
  InferenceService? inferenceService,
) {
  final navigator = Navigator.of(context);
  switch (index) {
    case 0:
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => HomeScreen(inferenceService: inferenceService),
          ),
        );
      }
    case 1:
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => HealthScreen(inferenceService: inferenceService),
        ),
      );
    case 2:
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const RelocationAssessmentScreenIT23185302(),
        ),
      );
    case 4:
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              EnvironmentDashboardScreen(inferenceService: inferenceService),
        ),
      );
  }
}

/// The selected apiary's hives, as the Monitor shows them. Empty when the
/// user has no apiary yet.
Future<List<HiveOption>> apiaryHivesProvider() async {
  final apiary = ApiaryService.instance.selectedApiary;
  if (apiary == null) return const [];
  final hives = await ApiaryService.instance.fetchHives(apiary.id);
  return [
    for (final hive in hives)
      HiveOption(id: hive.id, name: hive.name, apiary: apiary.locationName),
  ];
}
