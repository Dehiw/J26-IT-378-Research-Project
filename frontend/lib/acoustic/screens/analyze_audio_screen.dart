import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/theme.dart';
import '../acoustic_strings.dart';
import '../services/acoustic_service.dart';
import '../services/wav_waveform.dart';
import 'result_screen.dart';

/// Sends one audio file to [AcousticService] and shows "Analyzing hive
/// sound...". On success it replaces itself with the [ResultScreen]. On
/// failure it offers Retry, which sends the same bytes again.
class AnalyzeAudioScreen extends StatefulWidget {
  const AnalyzeAudioScreen({
    super.key,
    required this.service,
    required this.hiveId,
    required this.bytes,
    required this.filename,
    this.waveform = const [],
    this.onRecordAgain,
  });

  final AcousticService service;
  final String hiveId;
  final Uint8List bytes;
  final String filename;

  /// Live-recording samples for the preview. Empty for uploads.
  final List<double> waveform;

  /// Passed on to the Result screen.
  final VoidCallback? onRecordAgain;

  @override
  State<AnalyzeAudioScreen> createState() => _AnalyzeAudioScreenState();
}

class _AnalyzeAudioScreenState extends State<AnalyzeAudioScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  void _retry() {
    setState(() => _failed = false);
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final result = await widget.service.analyzeAudio(
        hiveId: widget.hiveId,
        bytes: widget.bytes,
        filename: widget.filename,
      );
      if (!mounted) return;
      // Uploads have no live levels, so draw the preview from the WAV bytes.
      // MP3 and other formats give null and show no preview.
      final waveform = widget.waveform.isNotEmpty
          ? widget.waveform
          : WavWaveform.decode(widget.bytes) ?? const <double>[];
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            service: widget.service,
            result: result,
            waveform: waveform,
            onRecordAgain: widget.onRecordAgain,
          ),
        ),
      );
    } catch (error, stack) {
      developer.log(
        'Analysis failed',
        name: 'AcousticAnalyze',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: Text(
          AcousticStrings.analysisResultTitle,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _failed ? _buildFailed() : _buildAnalyzing(),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzing() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: AppColors.accent),
        const SizedBox(height: 20),
        Text(
          AcousticStrings.analyzingHiveSound,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildFailed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AcousticStrings.analysisFailed,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 16, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _retry,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(120, 48),
            elevation: 0,
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.textPrimary,
            shape: const StadiumBorder(),
          ),
          child: Text(AcousticStrings.retry),
        ),
      ],
    );
  }
}
