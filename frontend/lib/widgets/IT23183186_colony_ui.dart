import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/theme.dart';
import 'environment_source.dart';

TextStyle colonyText(
  double size, [
  FontWeight weight = FontWeight.w500,
  Color color = AppColors.textPrimary,
]) => GoogleFonts.inter(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1.45,
);

class ColonySection extends StatelessWidget {
  final String title;
  final String? source;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  const ColonySection({
    super.key,
    required this.title,
    this.source,
    this.subtitle,
    this.icon = Icons.hive_outlined,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.border),
    ),
    child: Material(
      color: AppColors.bgCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (source != null) ...[
                SourceDot(source: source!, compact: true),
                const SizedBox(width: 8),
              ],
              Icon(icon, color: AppColors.accent3),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: colonyText(18, FontWeight.w700)),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: colonyText(12, FontWeight.w400, AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

class ColonyNotice extends StatelessWidget {
  final String message;
  final bool error;
  const ColonyNotice(this.message, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: error
          ? AppColors.error.withValues(alpha: .08)
          : AppColors.badgeLeafBg,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      message,
      style: colonyText(
        12,
        FontWeight.w500,
        error ? AppColors.error : AppColors.accent3,
      ),
    ),
  );
}
