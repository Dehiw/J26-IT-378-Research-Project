import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/utils/theme.dart';
import 'package:frontend/utils/acoustic/acoustic_strings.dart';
import 'package:frontend/models/acoustic/acoustic_result.dart';
import 'package:frontend/widgets/acoustic/acoustic_status_style.dart';

/// What the user picked in [HistoryFilterSheet]. [label] null means All.
class HistoryFilterChoice {
  const HistoryFilterChoice(this.label);

  final AcousticLabel? label;
}

/// Bottom sheet listing every status to filter Sound History by. Each option
/// has an icon and its name, so status is never shown by colour alone.
class HistoryFilterSheet extends StatelessWidget {
  const HistoryFilterSheet({super.key, required this.selected});

  /// Statuses that can be saved, so they are the only ones to filter by.
  /// Unclear results have no Save Result button and are never in history.
  static const List<AcousticLabel> filterLabels = [
    AcousticLabel.normal,
    AcousticLabel.queenless,
    AcousticLabel.swarming,
    AcousticLabel.stressAbnormal,
  ];

  /// The current filter; null when showing All.
  final AcousticLabel? selected;

  /// Shows the sheet. Returns null when dismissed without a choice.
  static Future<HistoryFilterChoice?> show(
    BuildContext context, {
    required AcousticLabel? selected,
  }) {
    // Scrollable, so the default 9/16-of-screen cap cannot cut off options
    // on a 360 x 640 phone.
    return showModalBottomSheet<HistoryFilterChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      builder: (_) => HistoryFilterSheet(selected: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                AcousticStrings.filterTitle,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _option(
              context,
              label: null,
              title: AcousticStrings.filterAll,
              icon: Icons.apps_outlined,
              iconColor: AppColors.textSecondary,
            ),
            for (final label in filterLabels)
              _option(
                context,
                label: label,
                title: AcousticStrings.labelTitle(label),
                icon: AcousticStatusStyle.of(label).icon,
                iconColor: AcousticStatusStyle.of(label).iconColor,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required AcousticLabel? label,
    required String title,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = label == selected;
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.accent)
          : null,
      selected: isSelected,
      onTap: () => Navigator.of(context).pop(HistoryFilterChoice(label)),
    );
  }
}
