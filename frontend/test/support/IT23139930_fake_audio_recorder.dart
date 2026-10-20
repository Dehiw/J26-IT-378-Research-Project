import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Test double for [AudioRecorder]. Tests push audio and config changes
/// through it, so the Recording flow runs without a microphone.
///
/// Each [startStream] call returns a new stream, as the real plugin does, so
/// a recording can be started again after it was stopped.
class FakeAudioRecorder implements AudioRecorder {
  StreamController<Uint8List>? _audio;

  /// Set to false to simulate a denied permission.
  bool permissionGranted = true;

  /// Set to an empty list to simulate no microphone.
  List<InputDevice> devices = const [
    InputDevice(id: 'test-mic', label: 'Test microphone'),
  ];

  /// Config passed to the most recent [startStream], for assertions.
  RecordConfig? startedWith;

  int startCount = 0;
  void Function(RecordConfig config)? _onConfigChanged;

  /// Simulates the platform reporting an adjusted format.
  void emitConfigChanged(RecordConfig config) => _onConfigChanged?.call(config);

  /// Simulates PCM audio arriving from the microphone. Ignored when no
  /// recording is running.
  void emitAudio(Uint8List pcm) => _audio?.add(pcm);

  @override
  Future<bool> hasPermission({bool request = true}) async => permissionGranted;

  @override
  Future<List<InputDevice>> listInputDevices() async => devices;

  @override
  Future<void> setOnConfigChanged(
    void Function(RecordConfig config)? callback,
  ) async {
    _onConfigChanged = callback;
  }

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    startCount++;
    startedWith = config;
    final audio = StreamController<Uint8List>();
    _audio = audio;
    return audio.stream;
  }

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream<Amplitude>.empty();

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {
    await _audio?.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
