import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/utils/theme.dart';
import 'package:frontend/utils/IT23139930_acoustic_strings.dart';
import 'package:frontend/models/IT23139930_hive_option.dart';

/// Shows the hive being monitored. Tapping it opens the hive picker, and
/// [onTap] is null when there is no hive to pick.
class HiveSelectorCard extends StatelessWidget {
  const HiveSelectorCard({super.key, required this.hive, this.onTap});

  final HiveOption? hive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selected = hive;
    return Material(
      color: AppColors.bgCard,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.badgeBeeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.hexagon_outlined,
                  color: AppColors.badgeBeeFg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected == null
                          ? AcousticStrings.noHivesFound
                          : selected.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (selected != null)
                      Text(
                        selected.apiary,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                AcousticStrings.selectHive,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: onTap == null
                      ? AppColors.textMuted
                      : AppColors.accent2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
