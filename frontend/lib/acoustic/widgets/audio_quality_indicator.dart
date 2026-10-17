import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/theme.dart';
import '../acoustic_strings.dart';
import '../services/signal_stats.dart';

/// "Audio quality: Good" pill. The state is shown with an icon and text,
/// not colour alone.
class AudioQualityIndicator extends StatelessWidget {
  const AudioQualityIndicator({super.key, required this.quality});

  final SignalQuality quality;

  @override
  Widget build(BuildContext context) {
    final (icon, color, value) = switch (quality) {
      SignalQuality.good => (
        Icons.check_circle_outline,
        AppColors.success,
        AcousticStrings.qualityGood,
      ),
      SignalQuality.fair => (
        Icons.warning_amber_outlined,
        AppColors.warning,
        AcousticStrings.qualityFair,
      ),
      SignalQuality.poor => (
        Icons.error_outline,
        AppColors.error,
        AcousticStrings.qualityPoor,
      ),
    };

    return Semantics(
      label: '${AcousticStrings.qualityLabel}: $value',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              '${AcousticStrings.qualityLabel}: $value',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.bgPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
