import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../utils/theme.dart';
import '../acoustic_config.dart';
import '../acoustic_strings.dart';
import '../models/abnormal_trend.dart';

/// Bar chart of abnormal results per day, drawn with plain Flutter widgets.
/// Each bar has its count as text, so the values do not depend on colour
/// or bar height alone.
class AbnormalityTrendCard extends StatelessWidget {
  const AbnormalityTrendCard({super.key, required this.trend});

  final AbnormalTrend trend;

  /// Height of the tallest bar.
  static const double _maxBarHeight = 96;

  @override
  Widget build(BuildContext context) {
    final title = AcousticStrings.abnormalTrendTitle(
      AcousticConfig.trendWindowDays,
    );
    final maxCount = trend.counts.fold<int>(0, math.max);
    final dayNames = [
      for (final day in trend.days) DateFormat('E').format(day),
    ];
    final summary = [
      for (var i = 0; i < trend.counts.length; i++)
        '${dayNames[i]} ${trend.counts[i]}',
    ].join(', ');

    return Semantics(
      label: '$title. $summary',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (trend.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  AcousticStrings.noAbnormalThisWeek,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              SizedBox(
                // Room for the count above, the bar, and the day name below.
                height: _maxBarHeight + 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < trend.counts.length; i++)
                      Expanded(
                        child: _Bar(
                          count: trend.counts[i],
                          maxCount: maxCount,
                          dayName: dayNames[i],
                          maxHeight: _maxBarHeight,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.count,
    required this.maxCount,
    required this.dayName,
    required this.maxHeight,
  });

  final int count;
  final int maxCount;
  final String dayName;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    // Zero counts get a thin grey base so the day still has a bar.
    final height = count == 0 || maxCount == 0
        ? 2.0
        : math.max(4.0, maxHeight * count / maxCount);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$count',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 18,
          height: height,
          decoration: BoxDecoration(
            color: count == 0 ? AppColors.border : AppColors.accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          dayName,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
