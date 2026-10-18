import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/theme.dart';
import '../acoustic_strings.dart';

/// Notice that results are made up. Shown only while the service reports
/// [AcousticService.isDemo]. Icon and text, so it does not rely on colour.
class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key, this.compact = false});

  /// Smaller text and padding, for the Monitor.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: AcousticStrings.demoNotice,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.badgeBeeBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.science_outlined,
              size: compact ? 16 : 18,
              color: AppColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AcousticStrings.demoNotice,
                style: GoogleFonts.inter(
                  fontSize: compact ? 12 : 13,
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
