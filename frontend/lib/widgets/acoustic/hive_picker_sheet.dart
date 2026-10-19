import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/utils/theme.dart';
import 'package:frontend/utils/acoustic/acoustic_strings.dart';
import 'package:frontend/models/acoustic/hive_option.dart';

/// Bottom sheet listing hives. Returns the chosen hive id, or null if
/// dismissed. Follows the same show() pattern as ImageSourceSheet.
class HivePickerSheet extends StatelessWidget {
  const HivePickerSheet({
    super.key,
    required this.hives,
    required this.selectedId,
  });

  final List<HiveOption> hives;
  final String? selectedId;

  static Future<String?> show(
    BuildContext context, {
    required List<HiveOption> hives,
    required String? selectedId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => HivePickerSheet(hives: hives, selectedId: selectedId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AcousticStrings.hiveSelectorTitle,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final hive in hives)
              _HiveRow(
                hive: hive,
                selected: hive.id == selectedId,
                onTap: () => Navigator.of(context).pop(hive.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _HiveRow extends StatelessWidget {
  const _HiveRow({
    required this.hive,
    required this.selected,
    required this.onTap,
  });

  final HiveOption hive;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${hive.name}, ${hive.apiary}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hive.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      hive.apiary,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
