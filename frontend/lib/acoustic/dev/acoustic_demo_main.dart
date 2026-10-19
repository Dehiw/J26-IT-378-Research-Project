import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:frontend/utils/theme.dart';
import 'package:frontend/models/acoustic/recording_capture.dart';
import 'package:frontend/screens/acoustic/acoustic_flows.dart';
import 'package:frontend/screens/acoustic/hive_sound_monitor_screen.dart';
import 'package:frontend/services/acoustic/file_picker_audio_picker.dart';
import 'package:frontend/services/acoustic/mock_acoustic_service.dart';
import 'package:frontend/acoustic/dev/wav_debug_saver.dart';

/// Stand-alone preview of the acoustic module on mock data. Used only for
/// development; the app itself is not changed.
///
/// Run with: flutter run -d windows -t lib/acoustic/dev/acoustic_demo_main.dart
void main() {
  runApp(const _AcousticDemoApp());
}

class _AcousticDemoApp extends StatefulWidget {
  const _AcousticDemoApp();

  @override
  State<_AcousticDemoApp> createState() => _AcousticDemoAppState();
}

class _AcousticDemoAppState extends State<_AcousticDemoApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final MockAcousticService _service = MockAcousticService();

  /// The most recent finished recording, for the debug save button.
  RecordingCapture? _lastCapture;

  Future<void> _saveLastCapture() async {
    final context = _navigatorKey.currentContext;
    final capture = _lastCapture;
    if (context == null) return;

    if (capture == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => const AlertDialog(
          content: Text('No recording yet. Record a hive sound first.'),
        ),
      );
      return;
    }

    final path = await WavDebugSaver.save(capture);
    if (!context.mounted || path == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug WAV saved'),
        content: SelectableText(
          '$path\n\nOpen it in Windows Media Player or VLC to check the '
          'sample rate, channels and bit depth.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Hive Sense: Acoustic demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: HiveSoundMonitorScreen(
        service: _service,
        filePicker: const FilePickerAudioPicker(),
        extraAppBarActions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Save last WAV (debug)',
              onPressed: _saveLastCapture,
            ),
        ],
        onRecordPressed: (hiveId) => AcousticFlows.startRecording(
          navigator: _navigatorKey.currentState!,
          service: _service,
          hiveId: hiveId,
          onCaptured: (capture) => _lastCapture = capture,
        ),
        onAudioPicked: (hiveId, audio) => AcousticFlows.analyzeUpload(
          navigator: _navigatorKey.currentState!,
          service: _service,
          hiveId: hiveId,
          audio: audio,
        ),
      ),
    );
  }
}
