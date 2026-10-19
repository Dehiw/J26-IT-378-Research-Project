import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/apiary_model.dart';
import '../utils/theme.dart';
import '../widgets/main_bottom_nav.dart';
import 'IT23183186_environment_dashboard_screen.dart';

/// Research Component IT23185302:
/// Hive Repositioning results — shows the uploaded land photo and the
/// candidate-zone area. Real analysis results are not connected yet, so this
/// screen shows an "Analysis not available yet" state instead of predictions.
class RepositioningResultsScreenIT23185302 extends StatelessWidget {
  final ApiaryModel apiary;
  final HiveModel hive;
  final File landPhoto;

  const RepositioningResultsScreenIT23185302({
    super.key,
    required this.apiary,
    required this.hive,
    required this.landPhoto,
  });

  static const int _currentNavIndex = 2; // Relocate is tab index 2

  void _onNavTapped(BuildContext context, int index) {
    final navigator = Navigator.of(context);
    if (index == _currentNavIndex) {
      // Back to the Relocation dashboard (results → repositioning → dashboard).
      var popped = 0;
      navigator.popUntil((route) => popped++ >= 2 || route.isFirst);
      return;
    }
    if (index == 0) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }
    if (index == 4) {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const EnvironmentDashboardScreen(),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Module tab $index will be available in the upcoming update.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.bgSecondary,
          ),
        ),
        backgroundColor: AppColors.panelBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary, size: 24),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Repositioning Results',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _buildSelectionSummary(),
              const SizedBox(height: 20),
              _buildSectionLabel('Apiary Land Photo'),
              const SizedBox(height: 10),
              _buildPhotoWithZonePlaceholder(),
              const SizedBox(height: 24),
              _buildSectionLabel('Analysis'),
              const SizedBox(height: 10),
              _buildAnalysisUnavailable(context),
              const SizedBox(height: 32),
            ],
          ).animate().fadeIn(duration: 350.ms),
        ),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: _currentNavIndex,
        onTap: (i) => _onNavTapped(context, i),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildSelectionSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              icon: Icons.location_on_outlined,
              label: 'Apiary',
              value: apiary.locationName,
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.border),
          const SizedBox(width: 14),
          Expanded(
            child: _SummaryItem(
              icon: Icons.hive_outlined,
              label: 'Hive Box',
              value: hive.name,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoWithZonePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(landPhoto, fit: BoxFit.cover),
                  // Placeholder layer where candidate zones will be drawn.
                  Container(
                    color: AppColors.panelBlack.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.panelBlack.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.ring.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.layers_outlined,
                              size: 16, color: AppColors.hiveTop),
                          const SizedBox(width: 8),
                          Text(
                            'Candidate zones will appear here',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.bgSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Land photo uploaded',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisUnavailable(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.bgElevated,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_empty_rounded,
                color: AppColors.hiveLow, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            'Analysis not available yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Land analysis is not connected yet. Candidate zones and hive position recommendations will be shown here once it is available.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.hiveLow,
              side: const BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(
              'Back to Repositioning',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.hiveLow),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
