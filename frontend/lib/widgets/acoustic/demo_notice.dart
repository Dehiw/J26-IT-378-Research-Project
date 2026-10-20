import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/utils/theme.dart';
import 'package:frontend/utils/acoustic/acoustic_strings.dart';

/// Notice about how far the result can be trusted. Shows the demo text while
/// [demo] is true (the mock service), otherwise the experimental-model text.
/// Icon and text, so it does not rely on colour.
class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key, this.compact = false, this.demo = true});

  /// True for made-up results (the mock). False for the real model.
  final bool demo;

  /// Smaller text and padding, for the Monitor.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = demo
        ? AcousticStrings.demoNotice
        : AcousticStrings.experimentalNotice;
    return Semantics(
      container: true,
      label: text,
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
                text,
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
