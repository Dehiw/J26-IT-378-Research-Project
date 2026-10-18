import 'package:flutter/material.dart';

import 'screens/acoustic_flows.dart';
import 'screens/hive_sound_monitor_screen.dart';
import 'services/acoustic_service.dart';
import 'services/file_picker_audio_picker.dart';
import 'services/mock_acoustic_service.dart';

// Step B, after origin/main is merged (it brings ApiaryService), add:
// import '../models/apiary_model.dart';
// import '../services/apiary_service.dart';
// import 'models/hive_option.dart';

/// The service the app uses. This is the one line to change when the real
/// backend service exists. Tests may replace it.
AcousticService acousticService = MockAcousticService(
  // Step B: hivesProvider: apiaryHivesProvider,
);

/// Opens Hive Sound Monitor. [hiveId] selects that hive; when null, the
/// first hive is selected. Completes when the user leaves the Monitor.
Future<void> openSoundMonitor(BuildContext context, {String? hiveId}) {
  final navigator = Navigator.of(context);
  final service = acousticService;
  return navigator.push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AcousticFlows.monitorRouteName),
      builder: (_) => HiveSoundMonitorScreen(
        service: service,
        initialHiveId: hiveId,
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

// Step B: the hive list from the main app. Uncomment after the merge.
//
// /// The selected apiary's hives, as the Monitor shows them. Empty when the
// /// user has no apiary yet.
// Future<List<HiveOption>> apiaryHivesProvider() async {
//   final apiary = ApiaryService.instance.selectedApiary;
//   if (apiary == null) return const [];
//   final hives = await ApiaryService.instance.fetchHives(apiary.id);
//   return [
//     for (final hive in hives)
//       HiveOption(id: hive.id, name: hive.name, apiary: apiary.locationName),
//   ];
// }
