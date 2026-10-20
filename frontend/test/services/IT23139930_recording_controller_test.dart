import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/IT23139930_recording_controller.dart';
import 'package:record/record.dart';

import '../support/IT23139930_fake_audio_recorder.dart';
import '../support/IT23139930_pcm_signal.dart';

/// Lets the stream listener receive queued audio before the test continues.
Future<void> flushEvents() => Future<void>.delayed(Duration.zero);

/// Waits for at least one controller tick (every 200 ms).
Future<void> waitForTick() =>
    Future<void>.delayed(const Duration(milliseconds: 600));

RecordingController controllerFor(
  FakeAudioRecorder recorder, {
  Duration noDataTimeout = const Duration(milliseconds: 50),
  Duration silenceTimeout = const Duration(milliseconds: 50),
}) {
  return RecordingController(
    hiveId: 'H-001',
    recorder: recorder,
    noDataTimeout: noDataTimeout,
    silenceTimeout: silenceTimeout,
  );
}

/// Simulates the platform reporting a different format.
void adjustFormat(
  FakeAudioRecorder recorder, {
  required int rate,
  required int channels,
}) {
  recorder.emitConfigChanged(
    RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: rate,
      numChannels: channels,
    ),
  );
}

void main() {
  group('format handling', () {
    test(
      'WAV header uses the requested format when nothing is adjusted',
      () async {
        final recorder = FakeAudioRecorder();
        final controller = controllerFor(recorder);

        await controller.start();
        final pcm = sine(seconds: 4, sampleRate: 16000);
        recorder.emitAudio(pcm);
        await flushEvents();
        await controller.stop();

        final capture = controller.capture!;
        final header = ByteData.sublistView(capture.wavBytes);
        expect(header.getUint32(24, Endian.little), 16000);
        expect(header.getUint16(22, Endian.little), 1);
        expect(capture.sampleRate, 16000);
        expect(capture.channels, 1);
        expect(capture.wavBytes.length, 44 + pcm.length);
        controller.dispose();
      },
    );

    test(
      'WAV header uses the actual format when the platform adjusts it',
      () async {
        final recorder = FakeAudioRecorder();
        final controller = controllerFor(recorder);

        await controller.start();
        adjustFormat(recorder, rate: 48000, channels: 2);
        final pcm = sine(seconds: 4, sampleRate: 48000, channels: 2);
        recorder.emitAudio(pcm);
        await flushEvents();
        await controller.stop();

        final capture = controller.capture!;
        final header = ByteData.sublistView(capture.wavBytes);
        expect(
          header.getUint32(24, Endian.little),
          48000,
          reason: 'sample rate',
        );
        expect(header.getUint16(22, Endian.little), 2, reason: 'channels');
        expect(
          header.getUint32(28, Endian.little),
          48000 * 2 * 2,
          reason: 'byte rate',
        );
        expect(header.getUint16(32, Endian.little), 4, reason: 'block align');
        expect(capture.sampleRate, 48000);
        expect(capture.channels, 2);
        controller.dispose();
      },
    );

    test('the 3-second minimum uses the actual format', () async {
      final recorder = FakeAudioRecorder();
      final controller = controllerFor(recorder);

      await controller.start();
      // 2 s of 48 kHz stereo is 384000 bytes. At the requested 16 kHz mono it
      // would look like 12 s and pass, so this only fails if the actual
      // format is used.
      adjustFormat(recorder, rate: 48000, channels: 2);
      recorder.emitAudio(sine(seconds: 2, sampleRate: 48000, channels: 2));
      await flushEvents();
      await controller.stop();

      expect(controller.phase, RecordingPhase.failed);
      expect(controller.failure, RecordingFailure.tooShort);
      expect(controller.capture, isNull);
      controller.dispose();
    });
  });

  group('no audio detection', () {
    test(
      'no data after the timeout is flagged, Poor, and stops as no audio',
      () async {
        final recorder = FakeAudioRecorder();
        final controller = controllerFor(recorder);

        await controller.start();
        await waitForTick();

        expect(controller.hasAudio, isFalse);
        expect(controller.soundMissing, isTrue);
        expect(controller.quality, SignalQuality.poor);

        await controller.stop();
        expect(controller.failure, RecordingFailure.noAudio);
        controller.dispose();
      },
    );

    test('silence for the timeout is flagged and Poor', () async {
      final recorder = FakeAudioRecorder();
      final controller = controllerFor(recorder);

      await controller.start();
      recorder.emitAudio(silence(seconds: 1, sampleRate: 16000));
      await flushEvents();
      await waitForTick();

      expect(controller.hasAudio, isTrue);
      expect(controller.soundMissing, isTrue);
      expect(controller.quality, SignalQuality.poor);

      await controller.stop();
      expect(controller.failure, RecordingFailure.noAudio);
      controller.dispose();
    });

    test('a normal signal clears the warning and is Good', () async {
      final recorder = FakeAudioRecorder();
      final controller = controllerFor(recorder);

      await controller.start();
      recorder.emitAudio(sine(seconds: 1, sampleRate: 16000));
      await flushEvents();
      await waitForTick();

      expect(controller.soundMissing, isFalse);
      expect(controller.quality, SignalQuality.good);
      controller.dispose();
    });

    test('the warning clears as soon as sound arrives after silence', () async {
      final recorder = FakeAudioRecorder();
      final controller = controllerFor(recorder);

      await controller.start();
      // Mic on, silent: the warning shows once the silence timeout passes.
      recorder.emitAudio(silence(seconds: 1, sampleRate: 16000));
      await flushEvents();
      await waitForTick();
      expect(controller.soundMissing, isTrue);
      expect(controller.quality, SignalQuality.poor);

      // Then the user speaks. The next chunk clears the warning at once,
      // without waiting for a timer tick.
      recorder.emitAudio(sine(seconds: 3, sampleRate: 16000));
      await flushEvents();
      expect(controller.soundMissing, isFalse);
      expect(controller.quality, SignalQuality.good);

      await controller.stop();
      expect(controller.phase, RecordingPhase.stopped);
      controller.dispose();
    });

    test('a long enough non-silent recording is kept', () async {
      final recorder = FakeAudioRecorder();
      final controller = controllerFor(recorder);

      await controller.start();
      recorder.emitAudio(sine(seconds: 4, sampleRate: 16000));
      await flushEvents();
      await controller.stop();

      expect(controller.phase, RecordingPhase.stopped);
      expect(controller.capture, isNotNull);
      controller.dispose();
    });

    test(
      'a short but non-silent recording is still reported as too short',
      () async {
        final recorder = FakeAudioRecorder();
        final controller = controllerFor(recorder);

        await controller.start();
        recorder.emitAudio(sine(seconds: 2, sampleRate: 16000));
        await flushEvents();
        await controller.stop();

        expect(controller.failure, RecordingFailure.tooShort);
        controller.dispose();
      },
    );

    test('a silent recording is reported as no audio, not too short', () async {
      final recorder = FakeAudioRecorder();
      final controller = controllerFor(recorder);

      await controller.start();
      recorder.emitAudio(silence(seconds: 5, sampleRate: 16000));
      await flushEvents();
      await controller.stop();

      expect(controller.failure, RecordingFailure.noAudio);
      controller.dispose();
    });
  });

  group('timer', () {
    test('Try Again starts the timer from zero', () async {
      final recorder = FakeAudioRecorder();
      final controller = controllerFor(
        recorder,
        noDataTimeout: const Duration(seconds: 30),
      );

      await controller.start();
      await waitForTick();
      expect(controller.elapsed, greaterThan(Duration.zero));

      recorder.emitAudio(sine(seconds: 1, sampleRate: 16000));
      await flushEvents();
      await controller.stop();
      expect(controller.failure, RecordingFailure.tooShort);

      await controller.start();
      expect(controller.elapsed, Duration.zero);
      await controller.cancel();
      controller.dispose();
    });
  });
}
