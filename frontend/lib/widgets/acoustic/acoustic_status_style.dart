import 'package:flutter/material.dart';

import 'package:frontend/utils/theme.dart';
import 'package:frontend/models/acoustic/acoustic_result.dart';

/// Icon and colours for each sound state. Colours come only from
/// [AppColors]. Status is never shown by colour alone: every use pairs
/// this style with the state's icon and text.
class AcousticStatusStyle {
  final IconData icon;
  final Color iconColor;
  final Color chipBackground;

  const AcousticStatusStyle({
    required this.icon,
    required this.iconColor,
    required this.chipBackground,
  });

  static AcousticStatusStyle of(AcousticLabel label) => switch (label) {
        AcousticLabel.normal => const AcousticStatusStyle(
            icon: Icons.check_circle_outline,
            iconColor: AppColors.success,
            chipBackground: AppColors.badgeLeafBg,
          ),
        AcousticLabel.queenless => const AcousticStatusStyle(
            icon: Icons.warning_amber_outlined,
            iconColor: AppColors.accent2,
            chipBackground: AppColors.badgeTempBg,
          ),
        AcousticLabel.swarming => const AcousticStatusStyle(
            icon: Icons.groups_outlined,
            iconColor: AppColors.warning,
            chipBackground: AppColors.badgeBeeBg,
          ),
        AcousticLabel.stressAbnormal => const AcousticStatusStyle(
            icon: Icons.graphic_eq,
            iconColor: AppColors.info,
            chipBackground: AppColors.badgeWaveBg,
          ),
        AcousticLabel.unclearRecording => const AcousticStatusStyle(
            icon: Icons.help_outline,
            iconColor: AppColors.textSecondary,
            chipBackground: AppColors.bgElevated,
          ),
      };
}
