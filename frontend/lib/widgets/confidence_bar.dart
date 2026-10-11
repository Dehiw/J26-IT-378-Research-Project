import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';

/// Animated horizontal confidence bar for a single class.
class ConfidenceBar extends StatelessWidget {
  final String label;
  final double confidence; // 0.0 – 1.0
  final bool isTopPrediction;
  final int animationDelayMs;

  const ConfidenceBar({
    super.key,
    required this.label,
    required this.confidence,
    this.isTopPrediction = false,
    this.animationDelayMs = 0,
  });

  Color get _barColor {
    if (isTopPrediction) {
      if (confidence >= 0.75) return AppColors.success;
      if (confidence >= 0.50) return AppColors.accent;
      return AppColors.warning;
    }
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [
        FadeEffect(
            delay: Duration(milliseconds: animationDelayMs),
            duration: 300.ms),
        SlideEffect(
          delay: Duration(milliseconds: animationDelayMs),
          duration: 300.ms,
          begin: const Offset(-0.1, 0),
          end: Offset.zero,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (isTopPrediction) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _barColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isTopPrediction
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isTopPrediction
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isTopPrediction ? _barColor : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(builder: (context, constraints) {
              return Stack(
                children: [
                  // Background track
                  Container(
                    width: constraints.maxWidth,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // Filled bar
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: confidence),
                    duration: Duration(milliseconds: 600 + animationDelayMs),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Container(
                        width: constraints.maxWidth * value,
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isTopPrediction
                                ? [
                                    _barColor,
                                    _barColor.withValues(alpha: 0.6)
                                  ]
                                : [
                                    AppColors.textMuted,
                                    AppColors.textMuted.withValues(alpha: 0.5)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    },
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
