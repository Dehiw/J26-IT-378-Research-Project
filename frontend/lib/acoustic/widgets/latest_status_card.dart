import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/theme.dart';
import '../acoustic_format.dart';
import '../acoustic_strings.dart';
import '../models/acoustic_result.dart';
import 'acoustic_status_style.dart';
import 'confidence_indicator.dart';
import 'status_chip.dart';
import 'waveform_view.dart';

/// Latest sound state for the selected hive, with confidence and, when
/// samples exist, the waveform preview. The preview is hidden when
/// [waveform] is null.
class LatestStatusCard extends StatelessWidget {
  const LatestStatusCard({
    super.key,
    required this.result,
    required this.waveform,
    required this.now,
  });

  final AcousticResult? result;
  final List<double>? waveform;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final latest = result;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AcousticStrings.latestSoundStatus.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (latest == null)
            Text(
              AcousticStrings.noAnalysesYet,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            )
          else ...[
            Row(
              children: [
                Flexible(
                  child: StatusChip(label: latest.displayLabel),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    AcousticFormat.dayAndTime(latest.recordedAt, now),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConfidenceIndicator(
              confidence: latest.confidence,
              color: AcousticStatusStyle.of(latest.displayLabel).iconColor,
            ),
          ],
          if (waveform != null) ...[
            const SizedBox(height: 16),
            WaveformView(amplitudes: waveform!),
          ],
        ],
      ),
    );
  }
}
