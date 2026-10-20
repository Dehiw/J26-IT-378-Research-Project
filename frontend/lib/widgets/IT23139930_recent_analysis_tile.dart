import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/utils/theme.dart';
import 'package:frontend/utils/IT23139930_acoustic_format.dart';
import 'package:frontend/utils/IT23139930_acoustic_strings.dart';
import 'package:frontend/models/IT23139930_acoustic_result.dart';
import 'package:frontend/widgets/IT23139930_acoustic_status_style.dart';

/// One row in the recent analyses list: state icon and name, then
/// confidence and day. Pass [onTap] to make the row open the result.
class RecentAnalysisTile extends StatelessWidget {
  const RecentAnalysisTile({
    super.key,
    required this.result,
    required this.now,
    this.onTap,
  });

  final AcousticResult result;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = result.displayLabel;
    final style = AcousticStatusStyle.of(label);
    final title = AcousticStrings.labelTitle(label);
    final percent = AcousticStrings.percent(result.confidence);
    final day = AcousticFormat.dayLabel(result.recordedAt, now);

    return Semantics(
      button: onTap != null,
      label: '$title, $percent confidence, $day',
      excludeSemantics: true,
      child: Material(
        color: AppColors.bgCard,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(style.icon, size: 18, color: style.iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '$percent · $day',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
