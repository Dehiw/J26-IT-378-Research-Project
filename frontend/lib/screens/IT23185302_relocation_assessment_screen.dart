import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/wild_bee_service.dart';
import '../utils/theme.dart';
import 'home_screen.dart';
import 'IT23183186_environment_dashboard_screen.dart';
import 'IT23185302_beekeeper_requests_screen.dart';
import 'IT23185302_hive_repositioning_screen.dart';
import 'IT23185302_post_relocation_monitoring_screen.dart';

/// Research Component IT23185302:
/// Beekeeper Relocation Hub — Dashboard with overview, services, and activity.
class RelocationAssessmentScreenIT23185302 extends StatefulWidget {
  const RelocationAssessmentScreenIT23185302({super.key});

  @override
  State<RelocationAssessmentScreenIT23185302> createState() =>
      _RelocationAssessmentScreenIT23185302State();
}

class _RelocationAssessmentScreenIT23185302State
    extends State<RelocationAssessmentScreenIT23185302> {
  final int _currentNavIndex = 2; // Relocate is tab index 2

  bool _loadingStats = true;
  int _pending = 0;
  int _active = 0;
  int _completed = 0;
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  bool _isAssignedToCurrentBeekeeper(
      Map<String, dynamic> report, UserModel? beekeeper) {
    if (beekeeper == null) return false;

    final bkId = (report['assigned_beekeeper_id'] ?? '').toString().trim();
    final bkName =
        (report['assigned_beekeeper'] ?? '').toString().trim().toLowerCase();
    final bkPhone = (report['assigned_phone'] ?? '').toString().trim();
    final bkEmail = (report['assigned_email'] ??
            report['assigned_beekeeper_email'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final currentId = beekeeper.id.trim();
    final currentName = beekeeper.name.trim().toLowerCase();
    final currentEmail = beekeeper.email.trim().toLowerCase();
    final currentPhone = (beekeeper.phone ?? '').trim();

    // 1. Match by Beekeeper ID
    if (currentId.isNotEmpty && bkId.isNotEmpty && bkId == currentId) {
      return true;
    }
    // 2. Match by Beekeeper Name
    if (currentName.isNotEmpty && bkName.isNotEmpty) {
      if (bkName == currentName ||
          bkName.contains(currentName) ||
          currentName.contains(bkName)) {
        return true;
      }
    }
    // 3. Match by Beekeeper Email
    if (currentEmail.isNotEmpty && bkEmail.isNotEmpty && bkEmail == currentEmail) {
      return true;
    }
    // 4. Match by Beekeeper Phone
    if (currentPhone.isNotEmpty && bkPhone.isNotEmpty && bkPhone == currentPhone) {
      return true;
    }
    return false;
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _loadingStats = true);
    try {
      final allReports = await WildBeeService.instance.fetchAllReports();
      final currentBeekeeper = AuthService.instance.currentUser;
      final reports = allReports
          .where((r) => _isAssignedToCurrentBeekeeper(r, currentBeekeeper))
          .toList();

      int pending = 0, active = 0, completed = 0;
      for (final r in reports) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        if (status == 'pending' || status == 'submitted') {
          pending++;
        } else if (status == 'accepted' || status == 'in_progress' || status == 'active') {
          active++;
        } else if (status == 'completed' || status == 'done' || status == 'closed') {
          completed++;
        }
      }
      // Most recent 5 for activity feed
      final recent = reports.take(5).toList();
      if (mounted) {
        setState(() {
          _pending = pending;
          _active = active;
          _completed = completed;
          _recentActivity = recent;
          _loadingStats = false;
        });
      }
    } catch (e) {
      developer.log('Error loading relocation stats: $e',
          name: 'RelocationHub');
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  void _onNavTapped(int index) {
    if (index == _currentNavIndex) return;
    if (index == 0) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
      return;
    }
    if (index == 4) {
      Navigator.of(context).push(
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
        automaticallyImplyLeading: false,
        title: Text(
          'Bee Keeper Relocate',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textPrimary, size: 22),
            tooltip: 'Refresh',
            onPressed: _loadStats,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.hiveLow,
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // ── Section 1: Relocation Overview ───────────────────
                _buildSectionLabel('Relocation Overview'),
                const SizedBox(height: 12),
                _buildOverviewCards(),

                const SizedBox(height: 28),

                // ── Section 2: Relocation Services ───────────────────
                _buildSectionLabel('Relocation Services'),
                const SizedBox(height: 12),
                _buildServiceCards(),

                const SizedBox(height: 28),

                // ── Section 3: Recent Relocation Activity ─────────────
                _buildSectionLabel('Recent Relocation Activity'),
                const SizedBox(height: 12),
                _buildRecentActivity(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Section label ─────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ── Overview stat cards ───────────────────────────────────────────

  Widget _buildOverviewCards() {
    if (_loadingStats) {
      return SizedBox(
        height: 88,
        child: Row(
          children: List.generate(
            3,
            (_) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.hiveLow),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 300.ms);
    }

    return Row(
      children: [
        _OverviewCard(
          label: 'Pending\nRequests',
          value: '$_pending',
          icon: Icons.pending_actions_rounded,
          iconBg: AppColors.badgeTempBg,
          iconColor: AppColors.accent2,
          valueColor: AppColors.accent2,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BeekeeperRequestsScreenIT23185302(
                  initialFilter: 'Pending',
                ),
              ),
            ).then((_) => _loadStats());
          },
        ),
        const SizedBox(width: 10),
        _OverviewCard(
          label: 'Active\nRelocations',
          value: '$_active',
          icon: Icons.sync_rounded,
          iconBg: AppColors.badgeBeeBg,
          iconColor: AppColors.hiveLow,
          valueColor: AppColors.hiveLow,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BeekeeperRequestsScreenIT23185302(
                  initialFilter: 'Accepted',
                ),
              ),
            ).then((_) => _loadStats());
          },
        ),
        const SizedBox(width: 10),
        _OverviewCard(
          label: 'Completed',
          value: '$_completed',
          icon: Icons.check_circle_outline_rounded,
          iconBg: AppColors.badgeLeafBg,
          iconColor: AppColors.success,
          valueColor: AppColors.success,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BeekeeperRequestsScreenIT23185302(
                  initialFilter: 'Completed',
                ),
              ),
            ).then((_) => _loadStats());
          },
        ),
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0);
  }

  // ── Service cards ─────────────────────────────────────────────────

  Widget _buildServiceCards() {
    return Column(
      children: [
        _ServiceCard(
          icon: Icons.bug_report_outlined,
          iconBg: AppColors.badgeTempBg,
          iconColor: AppColors.accent2,
          title: 'Wild Bee Relocation Requests',
          description:
              'View reported wild colonies, review assessments, and accept or decline requests.',
          actionLabel: 'View Requests',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BeekeeperRequestsScreenIT23185302(),
              ),
            ).then((_) => _loadStats());
          },
        ),
        const SizedBox(height: 12),
        _ServiceCard(
          icon: Icons.satellite_alt_rounded,
          iconBg: AppColors.badgeBeeBg,
          iconColor: AppColors.hiveLow,
          title: 'Hive Repositioning',
          description:
              'Upload an apiary land photo, analyze candidate zones, and recommend better hive positions within the same apiary.',
          actionLabel: 'Analyze Apiary',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const HiveRepositioningScreenIT23185302(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _ServiceCard(
          icon: Icons.videocam_outlined,
          iconBg: AppColors.badgeWaveBg,
          iconColor: AppColors.badgeWaveFg,
          title: 'Post-Relocation Monitoring',
          description:
              'Use ESP32-CAM to observe hive entrance activity after relocation.',
          actionLabel: 'View Monitoring',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const PostRelocationMonitoringScreenIT23185302(),
              ),
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0);
  }

  // ── Recent activity feed ──────────────────────────────────────────

  Widget _buildRecentActivity() {
    if (_loadingStats) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.hiveLow),
          ),
        ),
      );
    }

    if (_recentActivity.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 26,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No relocation activity yet.',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Once wild bee reports are submitted, they will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 350.ms);
    }

    return Column(
      children: _recentActivity.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        return _ActivityRow(
          report: r,
          index: i,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    BeekeeperRequestDetailsScreenIT23185302(request: r),
              ),
            ).then((_) => _loadStats());
          },
        );
      }).toList(),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0);
  }

  // ── Bottom Navigation Bar ─────────────────────────────────────────

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.bgPrimary,
      selectedItemColor: AppColors.hiveLow,
      unselectedItemColor: AppColors.textSecondary,
      showUnselectedLabels: true,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      currentIndex: _currentNavIndex,
      onTap: _onNavTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.monitor_heart_outlined),
          label: 'Health',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.location_on_outlined),
          label: 'Relocate',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.graphic_eq_rounded),
          label: 'Acoustic',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.eco_outlined),
          label: 'Environment',
        ),
      ],
    );
  }
}

// ── Overview stat card sub-widget ────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color valueColor;
  final VoidCallback? onTap;

  const _OverviewCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.border.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

// ── Service card sub-widget ───────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.border.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        actionLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.hiveLow,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.hiveLow,
                      ),
                    ],
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

// ── Recent activity row ───────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  final Map<String, dynamic> report;
  final int index;
  final VoidCallback? onTap;

  const _ActivityRow({
    required this.report,
    required this.index,
    this.onTap,
  });

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
      case 'closed':
        return AppColors.success;
      case 'accepted':
      case 'in_progress':
      case 'active':
        return AppColors.hiveLow;
      default:
        return AppColors.accent2;
    }
  }

  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
      case 'closed':
        return AppColors.badgeLeafBg;
      case 'accepted':
      case 'in_progress':
      case 'active':
        return AppColors.badgeBeeBg;
      default:
        return AppColors.badgeTempBg;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'submitted':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
      case 'active':
        return 'In Progress';
      case 'completed':
      case 'done':
      case 'closed':
        return 'Completed';
      default:
        return status.isNotEmpty
            ? '${status[0].toUpperCase()}${status.substring(1)}'
            : 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (report['status'] ?? 'pending').toString();
    final address = report['address']?.toString() ?? 'Unknown Location';
    final location = report['colony_location']?.toString() ?? '';
    final createdAt = report['created_at']?.toString() ?? '';
    final caseName = location.isNotEmpty ? '$location colony' : 'Wild Bee Case';

    // Format date simply
    String dateDisplay = createdAt;
    if (createdAt.length >= 10) dateDisplay = createdAt.substring(0, 10);

    final statusLabel = _statusLabel(status);
    final statusColor = _statusColor(status);
    final statusBg = _statusBg(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caseName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dateDisplay.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    dateDisplay,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    ),
  );
}
}

// ═══════════════════════════════════════════════════════════════════════════
// Wild Bee Assessment Form Screen (6-question decision support)
// Pushed when user taps "Wild Bee Relocation Requests"
// ═══════════════════════════════════════════════════════════════════════════

class _WildBeeAssessmentFormScreen extends StatefulWidget {
  const _WildBeeAssessmentFormScreen();

  @override
  State<_WildBeeAssessmentFormScreen> createState() =>
      _WildBeeAssessmentFormScreenState();
}

class _WildBeeAssessmentFormScreenState
    extends State<_WildBeeAssessmentFormScreen> {
  String? _selectedLocation;
  String? _selectedInsideStructure;
  String? _selectedHeight;
  String? _selectedAccessibility;
  String? _selectedBehavior;
  String? _selectedHumanProximity;
  bool _isSubmitting = false;

  void _submitAssessment() async {
    final missing = <String>[];
    if (_selectedLocation == null) missing.add('Location');
    if (_selectedInsideStructure == null) missing.add('Structure');
    if (_selectedHeight == null) missing.add('Height');
    if (_selectedAccessibility == null) missing.add('Accessibility');
    if (_selectedBehavior == null) missing.add('Bee Behavior');
    if (_selectedHumanProximity == null) missing.add('People Proximity');

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.bgSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Please answer all questions before submitting (${missing.length} remaining).',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.bgSecondary,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.accent2,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    developer.log(
      'Submitting wild colony assessment: Location=$_selectedLocation, Inside=$_selectedInsideStructure, Height=$_selectedHeight, Access=$_selectedAccessibility, Behavior=$_selectedBehavior, Proximity=$_selectedHumanProximity',
      name: 'RelocationAssessmentScreenIT23185302',
    );

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _showAssessmentResultSheet();
  }

  void _showAssessmentResultSheet() {
    final bool isHighUrgency = _selectedBehavior == 'Aggressive' ||
        (_selectedHumanProximity == 'High' && _selectedHeight == 'Below 2 m');
    final bool isInsideStructure = _selectedInsideStructure == 'Yes';

    String recommendationTitle;
    String recommendationDesc;
    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    if (isHighUrgency) {
      recommendationTitle = 'Priority Live Relocation Required';
      recommendationDesc =
          'Due to elevated bee defensiveness or high public proximity, professional live bee-rescue dispatch is strongly advised. Maintain a 6-meter clearance perimeter until assistance arrives.';
      statusColor = AppColors.error;
      statusBg = AppColors.badgeTempBg;
      statusIcon = Icons.emergency_rounded;
    } else if (isInsideStructure || _selectedAccessibility == 'Difficult') {
      recommendationTitle = 'Specialized Live Extraction Recommended';
      recommendationDesc =
          'The colony is located within structural cavity or challenging reach. A humane cut-out specialist equipped with gentle bee-vacuum hardware should be deployed to prevent property damage.';
      statusColor = AppColors.warning;
      statusBg = AppColors.badgeBeeBg;
      statusIcon = Icons.handyman_outlined;
    } else {
      recommendationTitle = 'Safe Standard Live Relocation Suitable';
      recommendationDesc =
          'Colony is in a manageable position with calm bee activity. A registered community beekeeper can safely collect and rehome this colony to a protected apiary.';
      statusColor = AppColors.success;
      statusBg = AppColors.badgeLeafBg;
      statusIcon = Icons.check_circle_outline_rounded;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Decision Support Result',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.hiveLow,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            recommendationTitle,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    recommendationDesc,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location_rounded,
                          size: 16, color: AppColors.hiveLow),
                      const SizedBox(width: 8),
                      Text(
                        '6.9271° N, 79.8612° E  •  GPS Confirmed',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.hiveLow,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Relocation dispatch notification sent successfully.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.bgSecondary,
                            ),
                          ),
                          backgroundColor: AppColors.panelBlack,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    child: Text(
                      'Confirm & Dispatch Notification',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Review Inputs',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          onPressed: () {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Relocation Assessment',
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
              const SizedBox(height: 12),
              _buildIntroBanner()
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.05, end: 0),
              const SizedBox(height: 24),

              _buildSectionHeader(
                questionNumber: '1',
                title: 'Where is the bee colony located?',
                subtitle:
                    'Select the primary surface where the cluster is anchored',
              ),
              const SizedBox(height: 12),
              _buildLocationSection(),
              const SizedBox(height: 26),

              _buildSectionHeader(
                questionNumber: '2',
                title: 'Is the colony inside a structure?',
                subtitle:
                    'Indicate whether bees have penetrated walls, ceilings, or cavities',
              ),
              const SizedBox(height: 12),
              _buildInsideStructureSection(),
              const SizedBox(height: 26),

              _buildSectionHeader(
                questionNumber: '3',
                title: 'Approximately how high is the colony?',
                subtitle:
                    'Helps determine whether ladders or lifting platforms are required',
              ),
              const SizedBox(height: 12),
              _buildHeightSection(),
              const SizedBox(height: 26),

              _buildSectionHeader(
                questionNumber: '4',
                title: 'How easy is it to access the colony location?',
                subtitle:
                    'Physical clearance and footing safety for relocation specialists',
              ),
              const SizedBox(height: 12),
              _buildAccessibilitySection(),
              const SizedBox(height: 26),

              _buildSectionHeader(
                questionNumber: '5',
                title: 'How are the bees behaving?',
                subtitle:
                    'Assess colony defensiveness from a safe observation distance',
              ),
              const SizedBox(height: 12),
              _buildBehaviorSection(),
              const SizedBox(height: 26),

              _buildSectionHeader(
                questionNumber: '6',
                title: 'Are many people normally close to this area?',
                subtitle:
                    'Identifies public stinging risk near walkways or home entrances',
              ),
              const SizedBox(height: 12),
              _buildProximitySection(),
              const SizedBox(height: 28),

              _buildTelemetryInfoCard().animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),
              _buildSubmitButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Intro banner ──────────────────────────────────────────────────

  Widget _buildIntroBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined,
                color: AppColors.textPrimary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.badgeBeeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'IT23185302 • DECISION SUPPORT',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.hiveLow,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tell us a few details about the bee colony. This will help us determine the safest next step.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required String questionNumber,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.hiveLow,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  questionNumber,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.bgSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ── Section 1: Location ───────────────────────────────────────────

  Widget _buildLocationSection() {
    final options = [
      {'title': 'Roof', 'icon': Icons.roofing_rounded, 'desc': 'Eaves & rafters'},
      {'title': 'Wall', 'icon': Icons.grid_view_rounded, 'desc': 'Cavities & vents'},
      {'title': 'Tree', 'icon': Icons.park_rounded, 'desc': 'Trunks & branches'},
      {'title': 'Other', 'icon': Icons.more_horiz_rounded, 'desc': 'Sheds & furniture'},
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final item = options[index];
        final title = item['title'] as String;
        final icon = item['icon'] as IconData;
        final desc = item['desc'] as String;
        final isSelected = _selectedLocation == title;

        return GestureDetector(
          onTap: () => setState(() => _selectedLocation = title),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.bgElevated : AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.hiveLow : AppColors.border,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.badgeBeeBg
                            : AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: isSelected
                            ? AppColors.hiveLow
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          size: 18, color: AppColors.hiveLow),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isSelected
                            ? AppColors.hiveDoor
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Section 2: Inside Structure ───────────────────────────────────

  Widget _buildInsideStructureSection() {
    final options = [
      {'title': 'Yes', 'icon': Icons.check_circle_outline_rounded},
      {'title': 'No', 'icon': Icons.highlight_off_rounded},
      {'title': 'Not sure', 'icon': Icons.help_outline_rounded},
    ];

    return Row(
      children: options.map((item) {
        final title = item['title'] as String;
        final icon = item['icon'] as IconData;
        final isSelected = _selectedInsideStructure == title;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _selectedInsideStructure = title),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.bgElevated : AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.hiveLow : AppColors.border,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: isSelected
                          ? AppColors.hiveLow
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Section 3: Height ─────────────────────────────────────────────

  Widget _buildHeightSection() {
    final options = [
      {
        'title': 'Below 2 m',
        'sub': 'Reachable standing from ground',
        'icon': Icons.vertical_align_bottom_rounded,
        'badge': 'Ground',
      },
      {
        'title': '2–5 m',
        'sub': 'Standard ladder reach level',
        'icon': Icons.height_rounded,
        'badge': 'Mid-level',
      },
      {
        'title': 'Above 5 m',
        'sub': 'Requires tall ladders or lift gear',
        'icon': Icons.vertical_align_top_rounded,
        'badge': 'Elevated',
      },
    ];

    return Column(
      children: options.map((item) {
        final title = item['title'] as String;
        final sub = item['sub'] as String;
        final icon = item['icon'] as IconData;
        final badge = item['badge'] as String;
        final isSelected = _selectedHeight == title;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => setState(() => _selectedHeight = title),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isSelected ? AppColors.bgElevated : AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.hiveLow : AppColors.border,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.badgeBeeBg
                          : AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? AppColors.hiveLow
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.hiveLow.withValues(alpha: 0.15)
                          : AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.hiveLow
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Section 4: Accessibility ──────────────────────────────────────

  Widget _buildAccessibilitySection() {
    final options = [
      {
        'title': 'Easy',
        'icon': Icons.sentiment_satisfied_rounded,
        'color': AppColors.success,
      },
      {
        'title': 'Moderate',
        'icon': Icons.sentiment_neutral_rounded,
        'color': AppColors.warning,
      },
      {
        'title': 'Difficult',
        'icon': Icons.sentiment_dissatisfied_rounded,
        'color': AppColors.error,
      },
    ];

    return Row(
      children: options.map((item) {
        final title = item['title'] as String;
        final icon = item['icon'] as IconData;
        final color = item['color'] as Color;
        final isSelected = _selectedAccessibility == title;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _selectedAccessibility = title),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.bgElevated : AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.hiveLow : AppColors.border,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: isSelected ? color : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Section 5: Bee Behavior ───────────────────────────────────────

  Widget _buildBehaviorSection() {
    final options = [
      {
        'title': 'Calm',
        'sub': 'Clustered, quiet, gentle flight',
        'color': AppColors.success,
        'icon': Icons.spa_outlined,
      },
      {
        'title': 'Active',
        'sub': 'Busy forage flight around nest',
        'color': AppColors.warning,
        'icon': Icons.air_rounded,
      },
      {
        'title': 'Aggressive',
        'sub': 'Defensive buzzing, chasing, stinging',
        'color': AppColors.error,
        'icon': Icons.bolt_rounded,
      },
      {
        'title': 'Not sure',
        'sub': 'Observed safely from far away',
        'color': AppColors.textSecondary,
        'icon': Icons.help_outline_rounded,
      },
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.4,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final item = options[index];
        final title = item['title'] as String;
        final sub = item['sub'] as String;
        final color = item['color'] as Color;
        final icon = item['icon'] as IconData;
        final isSelected = _selectedBehavior == title;

        return GestureDetector(
          onTap: () => setState(() => _selectedBehavior = title),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.bgElevated : AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.hiveLow : AppColors.border,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: isSelected ? color : AppColors.textSecondary,
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          size: 18, color: AppColors.hiveLow),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Section 6: Human Proximity ────────────────────────────────────

  Widget _buildProximitySection() {
    final options = [
      {
        'title': 'Low',
        'sub': 'Rarely visited garden or boundary',
        'icon': Icons.person_outline_rounded,
      },
      {
        'title': 'Medium',
        'sub': 'Moderate family or driveway footpaths',
        'icon': Icons.people_outline_rounded,
      },
      {
        'title': 'High',
        'sub': 'Busy doorway, porch, or public path',
        'icon': Icons.groups_rounded,
      },
    ];

    return Column(
      children: options.map((item) {
        final title = item['title'] as String;
        final sub = item['sub'] as String;
        final icon = item['icon'] as IconData;
        final isSelected = _selectedHumanProximity == title;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => setState(() => _selectedHumanProximity = title),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isSelected ? AppColors.bgElevated : AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.hiveLow : AppColors.border,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.badgeBeeBg
                          : AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? AppColors.hiveLow
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded,
                        size: 20, color: AppColors.hiveLow),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Telemetry info card ───────────────────────────────────────────

  Widget _buildTelemetryInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.badgeWaveBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.my_location_rounded,
                size: 20, color: AppColors.badgeWaveFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Automated Sensor Telemetry',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ready',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'GPS location and current weather will be collected automatically when the assessment is submitted.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit button ─────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.hiveLow,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _isSubmitting ? null : _submitAssessment,
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Evaluating Colony Relocation...',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Assess Relocation',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      color: AppColors.textPrimary, size: 20),
                ],
              ),
      ),
    );
  }
}

/// Convenience typedef matching component naming
typedef RelocationAssessmentScreen = RelocationAssessmentScreenIT23185302;
