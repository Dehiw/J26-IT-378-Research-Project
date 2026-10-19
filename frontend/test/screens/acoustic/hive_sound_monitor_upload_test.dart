import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/acoustic/acoustic_strings.dart';
import 'package:frontend/models/acoustic/acoustic_result.dart';
import 'package:frontend/screens/acoustic/hive_sound_monitor_screen.dart';
import 'package:frontend/services/acoustic/audio_upload.dart';

import '../../support/acoustic/fake_acoustic_service.dart';
import '../../support/acoustic/fake_audio_file_picker.dart';

Future<void> pumpMonitor(
  WidgetTester tester, {
  required FakeAcousticService service,
  AudioFilePicker? filePicker,
  Future<void> Function(String hiveId, PickedAudio audio)? onAudioPicked,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: HiveSoundMonitorScreen(
        service: service,
        filePicker: filePicker,
        onAudioPicked: onAudioPicked,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapUpload(WidgetTester tester) async {
  final button = find.text(AcousticStrings.uploadAudio);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

PickedAudio audio(String name, {int bytes = 2048}) =>
    PickedAudio(filename: name, bytes: Uint8List(bytes));

void main() {
  testWidgets('Upload is disabled when no file picker is supplied', (
    tester,
  ) async {
    await pumpMonitor(tester, service: FakeAcousticService());

    final button = tester.widget<OutlinedButton>(
      find.byWidgetPredicate((w) => w is OutlinedButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a valid WAV goes to the callback with the selected hive', (
    tester,
  ) async {
    final picker = FakeAudioFilePicker(next: audio('hive.wav'));
    String? hiveId;
    PickedAudio? picked;

    await pumpMonitor(
      tester,
      service: FakeAcousticService(),
      filePicker: picker,
      onAudioPicked: (id, file) async {
        hiveId = id;
        picked = file;
      },
    );
    await tapUpload(tester);

    expect(picker.pickCount, 1);
    expect(hiveId, 'H-001');
    expect(picked?.filename, 'hive.wav');
    expect(picked?.bytes.length, 2048);
  });

  testWidgets('an unsupported type shows a message and is not analysed', (
    tester,
  ) async {
    final picker = FakeAudioFilePicker(next: audio('notes.txt'));
    var analysed = false;

    await pumpMonitor(
      tester,
      service: FakeAcousticService(),
      filePicker: picker,
      onAudioPicked: (_, _) async => analysed = true,
    );
    await tapUpload(tester);

    expect(find.text(AcousticStrings.uploadUnsupportedType), findsOneWidget);
    expect(analysed, isFalse);
  });

  testWidgets('an empty file shows a message and is not analysed', (
    tester,
  ) async {
    final picker = FakeAudioFilePicker(next: audio('hive.wav', bytes: 0));
    var analysed = false;

    await pumpMonitor(
      tester,
      service: FakeAcousticService(),
      filePicker: picker,
      onAudioPicked: (_, _) async => analysed = true,
    );
    await tapUpload(tester);

    expect(find.text(AcousticStrings.uploadEmpty), findsOneWidget);
    expect(analysed, isFalse);
  });

  testWidgets(
    'a file over the size limit shows a message and is not analysed',
    (tester) async {
      final oversize = audio('hive.mp3', bytes: 10 * 1024 * 1024 + 1);
      final picker = FakeAudioFilePicker(next: oversize);
      var analysed = false;

      await pumpMonitor(
        tester,
        service: FakeAcousticService(),
        filePicker: picker,
        onAudioPicked: (_, _) async => analysed = true,
      );
      await tapUpload(tester);

      expect(
        find.text(AudioUploadValidator.message(AudioUploadProblem.tooLarge)),
        findsOneWidget,
      );
      expect(analysed, isFalse);
    },
  );

  testWidgets('a cancelled pick does nothing', (tester) async {
    final picker = FakeAudioFilePicker(next: null);
    var analysed = false;

    await pumpMonitor(
      tester,
      service: FakeAcousticService(),
      filePicker: picker,
      onAudioPicked: (_, _) async => analysed = true,
    );
    await tapUpload(tester);

    expect(picker.pickCount, 1);
    expect(analysed, isFalse);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('after an upload is saved, the Monitor reloads and lists it', (
    tester,
  ) async {
    final service = FakeAcousticService();
    final picker = FakeAudioFilePicker(next: audio('hive.wav'));

    await pumpMonitor(
      tester,
      service: service,
      filePicker: picker,
      onAudioPicked: (hiveId, file) async {
        // Stands in for the Analysis and Result flow: a saved result.
        await service.saveResult(
          testResult(
            id: 'uploaded',
            hiveId: hiveId,
            label: AcousticLabel.queenless,
          ),
        );
      },
    );
    expect(find.text(AcousticStrings.noAnalysesForHive), findsOneWidget);

    await tapUpload(tester);

    expect(find.text(AcousticStrings.noAnalysesForHive), findsNothing);
    expect(
      find.text(AcousticStrings.labelTitle(AcousticLabel.queenless)),
      findsWidgets,
    );
  });
}
