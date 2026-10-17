import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../utils/theme.dart';
import '../models/recording_capture.dart';
import '../screens/acoustic_flows.dart';
import '../screens/hive_sound_monitor_screen.dart';
import '../services/file_picker_audio_picker.dart';
import '../services/mock_acoustic_service.dart';
import 'wav_debug_saver.dart';

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
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          if (kDebugMode)
            Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: FloatingActionButton.extended(
                  heroTag: 'debug-save-wav',
                  onPressed: _saveLastCapture,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save last WAV'),
                ),
              ),
            ),
        ],
      ),
      home: HiveSoundMonitorScreen(
        service: _service,
        filePicker: const FilePickerAudioPicker(),
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
