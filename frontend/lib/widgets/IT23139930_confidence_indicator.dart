import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/utils/theme.dart';
import 'package:frontend/utils/IT23139930_acoustic_strings.dart';

/// "AI confidence" label, percentage and progress bar for one result.
/// The percentage text carries the value, so the bar is not the only cue.
class ConfidenceIndicator extends StatelessWidget {
  const ConfidenceIndicator({
    super.key,
    required this.confidence,
    required this.color,
  });

  /// Model confidence, 0-1.
  final double confidence;

  /// Bar colour, taken from the state's status style.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = confidence.clamp(0.0, 1.0);
    final percent = (clamped * 100).round();

    return Semantics(
      label: '${AcousticStrings.confidenceLabel} $percent percent',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                AcousticStrings.confidenceLabel,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 8,
              color: color,
              backgroundColor: AppColors.bgElevated,
            ),
          ),
        ],
      ),
    );
  }
}
