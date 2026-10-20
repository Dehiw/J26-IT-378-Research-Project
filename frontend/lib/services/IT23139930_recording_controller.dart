import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'package:frontend/utils/IT23139930_acoustic_config.dart';
import 'package:frontend/models/IT23139930_recording_capture.dart';
import 'package:frontend/services/IT23139930_microphone_permission.dart';
import 'package:frontend/services/IT23139930_signal_stats.dart';
import 'package:frontend/services/IT23139930_wav_encoder.dart';

export 'package:frontend/services/IT23139930_signal_stats.dart' show SignalQuality;

enum RecordingPhase { idle, starting, recording, stopped, failed }

enum RecordingFailure {
  permissionDenied,
  noMicrophone,
  recordingFailed,

  /// Stopped with no audio data, or with silence only.
  noAudio,
  tooShort,
}

/// Records hive sound as 16-bit PCM in memory, with live level readings,
/// a timer, the 30-second auto-stop, and checks for missing or silent audio.
///
/// All levels, durations and length checks are computed from the PCM bytes
/// actually received, using the format the platform actually uses.
///
/// Noise suppression, auto gain and echo cancel are switched off so the
/// captured sound matches the training data.
class RecordingController extends ChangeNotifier {
  RecordingController({
    required this.hiveId,
    AudioRecorder? recorder,
    this.noDataTimeout = AcousticConfig.noDataTimeout,
    this.silenceTimeout = AcousticConfig.silenceTimeout,
  }) : _recorder = recorder ?? AudioRecorder();

  final String hiveId;
  final AudioRecorder _recorder;

  /// How long without any audio bytes before the mic counts as not
  /// delivering sound. Injectable for tests.
  final Duration noDataTimeout;

  /// How long continuous silence lasts before the warning shows.
  final Duration silenceTimeout;

  RecordingPhase _phase = RecordingPhase.idle;
  RecordingFailure? _failure;
  RecordingCapture? _capture;
  Duration _elapsed = Duration.zero;
  final List<double> _levels = [];
  final BytesBuilder _pcm = BytesBuilder(copy: false);
  final Stopwatch _stopwatch = Stopwatch();

  int _bytesReceived = 0;
  SignalStats _latest = SignalStats();
  SignalStats _overall = SignalStats();
  Duration? _silentSince;
  bool _loggedMissing = false;

  SignalStats _bucket = SignalStats();
  int _bucketBytes = 0;

  StreamSubscription<Uint8List>? _audioSub;
  Timer? _ticker;
  bool _finishing = false;

  /// Format the plugin actually uses. Starts as the requested format and is
  /// replaced if the platform reports an adjustment. The WAV header is always
  /// written from these values.
  int _actualSampleRate = AcousticConfig.recordingSampleRate;
  int _actualChannels = AcousticConfig.recordingChannels;

  RecordingPhase get phase => _phase;
  RecordingFailure? get failure => _failure;
  RecordingCapture? get capture => _capture;
  Duration get elapsed => _elapsed;

  bool get isRecording => _phase == RecordingPhase.recording;

  /// True once any audio bytes have arrived in this recording.
  bool get hasAudio => _bytesReceived > 0;

  /// True when no audio has arrived after [noDataTimeout], or when the level
  /// has been silent for [silenceTimeout]. The screen shows a banner.
  bool get soundMissing => _noDataReached || _silenceReached;

  bool get _noDataReached =>
      isRecording && !hasAudio && _elapsed >= noDataTimeout;

  bool get _silenceReached {
    final silentSince = _silentSince;
    if (!isRecording || silentSince == null) return false;
    return _stopwatch.elapsed - silentSince >= silenceTimeout;
  }

  /// Live quality. No audio or silence is always Poor.
  SignalQuality get quality {
    if (soundMissing) return SignalQuality.poor;
    return SignalQualityRules.classify(
      hasAudio: hasAudio,
      rmsDb: _latest.rmsDb,
      clippedRatio: _overall.clippedRatio,
    );
  }

  /// The newest [count] waveform bars, left-padded with zeros. Each bar is
  /// [AcousticConfig.waveformBucket] of audio.
  List<double> recentLevels({int count = 40}) {
    final start = _levels.length > count ? _levels.length - count : 0;
    final recent = _levels.sublist(start);
    return [...List<double>.filled(count - recent.length, 0), ...recent];
  }

  /// Asks for permission and starts capturing. Safe to call again after a
  /// failure. Resets the timer and all recording state first.
  Future<void> start() async {
    if (_phase == RecordingPhase.starting || isRecording) return;
    _resetForNewRecording();
    _setPhase(RecordingPhase.starting);

    try {
      final access = await MicrophonePermission.request(_recorder);
      if (access != MicrophoneAccess.granted) {
        _fail(RecordingFailure.permissionDenied);
        return;
      }

      final devices = await _recorder.listInputDevices();
      if (kDebugMode) {
        debugPrint(
          'Recording start: permission=$access, input devices='
          '${devices.map((d) => d.label).join(', ')}',
        );
      }
      if (devices.isEmpty) {
        _fail(RecordingFailure.noMicrophone);
        return;
      }

      _actualSampleRate = AcousticConfig.recordingSampleRate;
      _actualChannels = AcousticConfig.recordingChannels;
      await _recorder.setOnConfigChanged((config) {
        // Called only when the platform changed a requested value.
        _actualSampleRate = config.sampleRate;
        _actualChannels = config.numChannels;
      });

      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: AcousticConfig.recordingSampleRate,
          numChannels: AcousticConfig.recordingChannels,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
      _audioSub = stream.listen(
        _onChunk,
        onError: (Object _) => _fail(RecordingFailure.recordingFailed),
      );

      _stopwatch
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), _onTick);
      _setPhase(RecordingPhase.recording);
    } catch (error, stack) {
      debugPrint('Recording failed to start: $error\n$stack');
      await _tearDown();
      _fail(RecordingFailure.recordingFailed);
    }
  }

  /// Ends the recording and builds the WAV capture. Called by the Stop
  /// button and by the auto-stop at [AcousticConfig.maxRecordingDuration].
  Future<void> stop() async {
    if (!isRecording || _finishing) return;
    _finishing = true;

    try {
      final elapsedAtStop = _stopwatch.elapsed;
      await _tearDown();
      final pcm = _pcm.takeBytes();
      final sampleRate = _actualSampleRate;
      final channels = _actualChannels;
      final seconds = WavEncoder.durationSeconds(
        pcm16Length: pcm.length,
        sampleRate: sampleRate,
        channels: channels,
      );
      final overall = SignalStats.fromPcm16(pcm);

      if (kDebugMode) {
        debugPrint(
          'Recording stop: elapsed ${elapsedAtStop.inMilliseconds} ms, '
          'PCM bytes ${pcm.length}, actual format $sampleRate Hz / '
          '$channels ch / 16-bit (requested '
          '${AcousticConfig.recordingSampleRate} Hz / '
          '${AcousticConfig.recordingChannels} ch), derived duration '
          '${(seconds * 1000).round()} ms, RMS '
          '${overall.rmsDb.toStringAsFixed(1)} dBFS, peak '
          '${overall.peakDb.toStringAsFixed(1)} dBFS.',
        );
      }

      if (pcm.isEmpty || overall.isSilent) {
        _fail(RecordingFailure.noAudio);
        return;
      }
      if (seconds < AcousticConfig.minRecordingDuration.inMilliseconds / 1000) {
        _fail(RecordingFailure.tooShort);
        return;
      }

      final wav = WavEncoder.encodePcm16(
        pcm16: pcm,
        sampleRate: sampleRate,
        channels: channels,
      );
      _capture = RecordingCapture(
        wavBytes: wav,
        filename: _filenameFor(DateTime.now()),
        waveform: List.unmodifiable(_levels),
        duration: Duration(milliseconds: (seconds * 1000).round()),
        sampleRate: sampleRate,
        channels: channels,
      );
      _setPhase(RecordingPhase.stopped);
    } catch (error, stack) {
      debugPrint('Recording failed to stop: $error\n$stack');
      _fail(RecordingFailure.recordingFailed);
    } finally {
      _finishing = false;
    }
  }

  /// Stops and throws the audio away. Nothing is analysed.
  Future<void> cancel() async {
    if (_phase == RecordingPhase.starting || isRecording) {
      await _tearDown();
    }
    _resetForNewRecording();
    _setPhase(RecordingPhase.idle);
  }

  /// Returns to idle after a failure or a finished recording.
  void reset() {
    _resetForNewRecording();
    _setPhase(RecordingPhase.idle);
  }

  void _onChunk(Uint8List chunk) {
    _bytesReceived += chunk.length;
    _pcm.add(chunk);

    _latest = SignalStats.fromPcm16(chunk);
    _overall.addPcm16(chunk);
    if (_latest.isSilent) {
      _silentSince ??= _stopwatch.elapsed;
    } else {
      _silentSince = null;
    }

    _bucket.addPcm16(chunk);
    _bucketBytes += chunk.length;
    if (_bucketBytes >= _waveformBucketBytes()) {
      _levels.add(_barHeight(_bucket.rmsDb));
      _bucket = SignalStats();
      _bucketBytes = 0;
    }
    notifyListeners();
  }

  /// Bytes in one waveform bar, using the actual format.
  int _waveformBucketBytes() {
    final bytesPerSecond = _actualSampleRate * _actualChannels * 2;
    return bytesPerSecond *
        AcousticConfig.waveformBucket.inMilliseconds ~/
        1000;
  }

  /// Maps -60 dBFS to 0 and 0 dBFS to 1.
  static double _barHeight(double db) => ((db + 60) / 60).clamp(0.0, 1.0);

  void _onTick(Timer _) {
    _elapsed = _stopwatch.elapsed;
    if (_elapsed >= AcousticConfig.maxRecordingDuration) {
      stop();
      return;
    }
    if (soundMissing && !_loggedMissing) {
      _loggedMissing = true;
      if (kDebugMode) {
        final silentFor = _silentSince == null
            ? Duration.zero
            : _stopwatch.elapsed - _silentSince!;
        debugPrint(
          'Sound missing at ${_elapsed.inMilliseconds} ms: PCM bytes '
          '$_bytesReceived, silent for ${silentFor.inMilliseconds} ms.',
        );
      }
    }
    notifyListeners();
  }

  /// Stops the timer and the audio stream. The cancel is not awaited, so
  /// teardown finishes even if a platform stream never completes its cancel.
  Future<void> _tearDown() async {
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    unawaited(_audioSub?.cancel());
    _audioSub = null;
    try {
      await _recorder.stop();
    } catch (error) {
      debugPrint('Recorder stop error (ignored): $error');
    }
  }

  void _resetForNewRecording() {
    _failure = null;
    _capture = null;
    _elapsed = Duration.zero;
    _levels.clear();
    _pcm.takeBytes();
    _bytesReceived = 0;
    _latest = SignalStats();
    _overall = SignalStats();
    _silentSince = null;
    _loggedMissing = false;
    _bucket = SignalStats();
    _bucketBytes = 0;
    _stopwatch
      ..stop()
      ..reset();
  }

  void _fail(RecordingFailure failure) {
    _failure = failure;
    _setPhase(RecordingPhase.failed);
  }

  void _setPhase(RecordingPhase phase) {
    _phase = phase;
    notifyListeners();
  }

  String _filenameFor(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${time.year}${two(time.month)}${two(time.day)}_'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
    return 'hive_${hiveId}_$stamp.wav';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _audioSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
