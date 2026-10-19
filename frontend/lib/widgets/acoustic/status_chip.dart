import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/utils/theme.dart';
import 'package:frontend/utils/acoustic/acoustic_strings.dart';
import 'package:frontend/models/acoustic/acoustic_result.dart';
import 'package:frontend/widgets/acoustic/acoustic_status_style.dart';

/// Pill showing a sound state as icon + text on a pastel background.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label});

  final AcousticLabel label;

  @override
  Widget build(BuildContext context) {
    final style = AcousticStatusStyle.of(label);
    final title = AcousticStrings.labelTitle(label);

    return Semantics(
      label: title,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: style.chipBackground,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 16, color: style.iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
