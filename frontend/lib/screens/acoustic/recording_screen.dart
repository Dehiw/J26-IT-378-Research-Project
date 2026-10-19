import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/utils/theme.dart';
import 'package:frontend/utils/acoustic/acoustic_config.dart';
import 'package:frontend/utils/acoustic/acoustic_format.dart';
import 'package:frontend/utils/acoustic/acoustic_strings.dart';
import 'package:frontend/models/acoustic/hive_names.dart';
import 'package:frontend/models/acoustic/recording_capture.dart';
import 'package:frontend/services/acoustic/acoustic_service.dart';
import 'package:frontend/services/acoustic/microphone_permission.dart';
import 'package:frontend/services/acoustic/recording_controller.dart';
import 'package:frontend/widgets/acoustic/audio_quality_indicator.dart';
import 'package:frontend/widgets/acoustic/recording_mic_button.dart';
import 'package:frontend/widgets/acoustic/waveform_view.dart';
import 'package:frontend/screens/acoustic/analyze_audio_screen.dart';

/// Records one hive sound, then sends it to [AcousticService] for analysis.
class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    super.key,
    required this.service,
    required this.hiveId,
    this.controller,
    this.onCaptured,
    this.onRecordAgain,
  });

  final AcousticService service;
  final String hiveId;

  /// Injected for tests. When null, the screen creates and disposes its own.
  final RecordingController? controller;

  /// Called once a recording is finished, before analysis. Used by the dev
  /// entry to keep the last WAV for inspection.
  final ValueChanged<RecordingCapture>? onCaptured;

  /// Passed on to the analysis and result screens.
  final VoidCallback? onRecordAgain;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  late final RecordingController _controller =
      widget.controller ?? RecordingController(hiveId: widget.hiveId);

  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (widget.controller == null) {
      // Stop the microphone before releasing the controller.
      unawaited(_controller.cancel().whenComplete(_controller.dispose));
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_controller.phase == RecordingPhase.stopped &&
        !_handedOff &&
        _controller.capture != null) {
      _handedOff = true;
      widget.onCaptured?.call(_controller.capture!);
      _openAnalysis(_controller.capture!);
      return;
    }
    setState(() {});
  }

  /// Replaces this screen with the analysis of the finished recording.
  void _openAnalysis(RecordingCapture capture) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AnalyzeAudioScreen(
          service: widget.service,
          hiveId: widget.hiveId,
          bytes: capture.wavBytes,
          filename: capture.filename,
          waveform: capture.waveform,
          onRecordAgain: widget.onRecordAgain,
        ),
      ),
    );
  }

  Future<void> _onBack() async {
    if (_controller.phase == RecordingPhase.starting ||
        _controller.isRecording) {
      await _controller.cancel();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          !(_controller.isRecording ||
              _controller.phase == RecordingPhase.starting),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.panelBlack,
        appBar: AppBar(
          backgroundColor: AppColors.panelBlack,
          foregroundColor: AppColors.bgPrimary,
          elevation: 0,
          leading: BackButton(color: AppColors.bgPrimary, onPressed: _onBack),
          title: Text(
            AcousticStrings.recordingTitle,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.bgPrimary,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _HiveTag(hiveId: widget.hiveId),
            ),
          ],
        ),
        body: SafeArea(child: _buildRecordingBody()),
      ),
    );
  }

  Widget _buildRecordingBody() {
    final phase = _controller.phase;
    final busy = phase == RecordingPhase.starting;
    final recording = _controller.isRecording;
    final failure = _controller.failure;
    final max = AcousticConfig.maxRecordingDuration;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          RecordingMicButton(
            recording: recording,
            onPressed: busy
                ? null
                : (recording ? _controller.stop : _controller.start),
          ),
          const SizedBox(height: 24),
          _TimerText(elapsed: _controller.elapsed, max: max),
          const SizedBox(height: 12),
          if (recording)
            AudioQualityIndicator(quality: _controller.quality)
          else
            const SizedBox(height: 36),
          if (recording && _controller.soundMissing) ...[
            const SizedBox(height: 12),
            _SoundMissingBanner(
              text: AcousticStrings.soundMissingText(
                android: MicrophonePermission.isAndroid,
              ),
            ),
          ],
          const SizedBox(height: 16),
          WaveformView(
            amplitudes: _controller.recentLevels(),
            color: AppColors.accent,
          ),
          const SizedBox(height: 12),
          Text(
            recording
                ? AcousticStrings.recordingHelper
                : AcousticStrings.tapToStart,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AcousticStrings.recordingLengthHint(max.inSeconds),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (failure != null) ...[
            const SizedBox(height: 20),
            _FailureCard(failure: failure, onTryAgain: _controller.start),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: busy
                ? null
                : (recording ? _controller.stop : _controller.start),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              elevation: 0,
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textPrimary,
              disabledBackgroundColor: AppColors.bgElevated,
              disabledForegroundColor: AppColors.textMuted,
              shape: const StadiumBorder(),
            ),
            child: Text(
              recording
                  ? AcousticStrings.stopRecording
                  : AcousticStrings.startRecording,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (recording || busy)
            TextButton(
              onPressed: busy ? null : _controller.cancel,
              child: Text(
                AcousticStrings.cancelRecording,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.bgPrimary,
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// "Hive H-001" tag in the top right.
class _HiveTag extends StatelessWidget {
  const _HiveTag({required this.hiveId});

  final String hiveId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        HiveNames.of(hiveId),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

/// Warning shown when the microphone delivers no sound. Icon and text.
class _SoundMissingBanner extends StatelessWidget {
  const _SoundMissingBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.mic_off_outlined,
              size: 20,
              color: AppColors.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.bgPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "00:18 / 00:30" timer.
class _TimerText extends StatelessWidget {
  const _TimerText({required this.elapsed, required this.max});

  final Duration elapsed;
  final Duration max;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(
      fontSize: 40,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: AcousticFormat.clock(elapsed),
            style: style.copyWith(color: AppColors.bgPrimary),
          ),
          TextSpan(
            text: ' / ${AcousticFormat.clock(max)}',
            style: style.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Shows why recording stopped, with the next step.
class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.failure, required this.onTryAgain});

  final RecordingFailure failure;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure) {
      RecordingFailure.permissionDenied =>
        MicrophonePermission.isAndroid
            ? AcousticStrings.micPermissionDeniedAndroid
            : AcousticStrings.micPermissionBlockedWindows,
      RecordingFailure.noMicrophone => AcousticStrings.noMicrophone,
      RecordingFailure.noAudio =>
        '${AcousticStrings.noAudioCaptured} '
            '${AcousticStrings.soundMissingText(android: MicrophonePermission.isAndroid)}',
      RecordingFailure.recordingFailed => AcousticStrings.recordingFailed,
      RecordingFailure.tooShort => AcousticStrings.recordingTooShort,
    };
    final isPermission = failure == RecordingFailure.permissionDenied;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPermission)
            Text(
              AcousticStrings.micPermissionTitle,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.bgPrimary,
              ),
            ),
          if (isPermission) const SizedBox(height: 6),
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.bgPrimary),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onTryAgain,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.bgPrimary,
              side: const BorderSide(color: AppColors.textSecondary),
              shape: const StadiumBorder(),
            ),
            child: Text(AcousticStrings.tryAgain),
          ),
        ],
      ),
    );
  }
}
