import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/utils/theme.dart';
import 'package:frontend/utils/acoustic/acoustic_format.dart';
import 'package:frontend/utils/acoustic/acoustic_strings.dart';
import 'package:frontend/models/acoustic/acoustic_result.dart';
import 'package:frontend/models/acoustic/hive_names.dart';
import 'package:frontend/screens/acoustic/acoustic_flows.dart';
import 'package:frontend/services/acoustic/acoustic_service.dart';
import 'package:frontend/widgets/acoustic/acoustic_status_style.dart';
import 'package:frontend/widgets/acoustic/confidence_indicator.dart';
import 'package:frontend/widgets/acoustic/demo_notice.dart';
import 'package:frontend/widgets/acoustic/waveform_view.dart';

/// Result of one analysis. The user either saves it, which returns to the
/// Monitor, or records again. An unclear recording can only be recorded
/// again.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.service,
    required this.result,
    this.waveform = const [],
    this.onRecordAgain,
    this.readOnly = false,
  });

  final AcousticService service;
  final AcousticResult result;

  /// Normalised 0-1 samples from the recording. Empty for uploads, which
  /// hides the preview.
  final List<double> waveform;

  /// Starts a new recording. Null hides the button.
  final VoidCallback? onRecordAgain;

  /// True when opened from Sound History: no Save Result and no Record
  /// Again, only the back button.
  final bool readOnly;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _saving = false;
  bool _saveFailed = false;

  bool get _isUnclear =>
      widget.result.displayLabel == AcousticLabel.unclearRecording;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.service.saveResult(widget.result, waveform: widget.waveform);
      if (!mounted) return;
      AcousticFlows.resultSaved.value++;
      AcousticFlows.backToMonitor(Navigator.of(context));
    } catch (error, stack) {
      developer.log(
        'Saving result failed',
        name: 'AcousticResult',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final label = result.displayLabel;
    final style = AcousticStatusStyle.of(label);

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              DemoNotice(demo: widget.service.isDemo),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: style.chipBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, size: 40, color: style.iconColor),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AcousticStrings.labelTitle(label),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${HiveNames.of(result.hiveId)} · '
                '${AcousticFormat.dayAndTime(result.recordedAt, DateTime.now())}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _Card(
                child: ConfidenceIndicator(
                  confidence: result.confidence,
                  color: style.iconColor,
                ),
              ),
              if (widget.waveform.isNotEmpty) ...[
                const SizedBox(height: 16),
                WaveformView(amplitudes: widget.waveform),
              ],
              const SizedBox(height: 16),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AcousticStrings.whatThisMeans,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AcousticStrings.labelMeaning(label),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isUnclear) ...[
                const SizedBox(height: 16),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AcousticStrings.unclearTipsTitle,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final tip in AcousticStrings.unclearTips)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '• $tip',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                AcousticStrings.guidanceNote,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              if (_saveFailed) ...[
                Text(
                  AcousticStrings.saveFailed,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!_isUnclear && !widget.readOnly) ...[
                ElevatedButton(
                  onPressed: _saving ? null : _save,
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
                    _saving
                        ? AcousticStrings.savingResult
                        : AcousticStrings.saveResult,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.onRecordAgain != null && !widget.readOnly)
                OutlinedButton.icon(
                  onPressed: _saving ? null : widget.onRecordAgain,
                  icon: const Icon(Icons.mic_none),
                  label: Text(
                    AcousticStrings.recordAgain,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    foregroundColor: AppColors.textPrimary,
                    disabledForegroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.accent),
                    shape: const StadiumBorder(),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// White rounded card used for the result sections.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: child,
    );
  }
}
