import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/inference_service.dart';
import '../services/wild_bee_service.dart';
import '../utils/theme.dart';
import 'login_screen.dart';
import 'home_screen.dart' show homeRouteObserver;
import 'IT23185302_wild_bee_hive_report_screen.dart';
import 'IT23185302_my_requests_screen.dart';
import 'IT23185302_beekeepers_directory_screen.dart';

/// Dedicated Home Page for Wild Bee Hive / Normal Users.
/// Focused on wild colony discovery reporting, relocation tracking,
/// beekeepers directory access, and bee safety/conservation education.
class NormalUserHomeScreen extends StatefulWidget {
  final InferenceService? inferenceService;

  const NormalUserHomeScreen({super.key, this.inferenceService});

  @override
  State<NormalUserHomeScreen> createState() => _NormalUserHomeScreenState();
}

class _NormalUserHomeScreenState extends State<NormalUserHomeScreen>
    with RouteAware {
  final int _currentIndex = 0;

  // Live stats
  int _myReportCount = 0;
  int _activeBeekeeperCount = 0;
  int _completedCount = 0;
  bool _loadingStats = true;
  List<Map<String, dynamic>> _myReports = [];

  @override
  void initState() {
    super.initState();
    if (!AuthService.instance.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                LoginScreen(inferenceService: widget.inferenceService),
          ),
          (route) => false,
        );
      });
      return;
    }
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    homeRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    homeRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final reports = await WildBeeService.instance.fetchMyReports();
      final bkRes = await AuthService.instance.fetchRegisteredBeekeepers();

      final completed = reports
          .where(
            (r) => (r['status'] ?? '').toString().toLowerCase() == 'completed',
          )
          .length;

      if (mounted) {
        setState(() {
          _myReports = reports;
          _myReportCount = reports.length;
          _activeBeekeeperCount = bkRes.length;
          _completedCount = completed;
          _loadingStats = false;
        });
      }
    } catch (e) {
      developer.log('Normal user stats load error: $e',
          name: 'NormalUserHomeScreen');
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  void _onNavTapped(int index) {
    if (index == 0) return;

    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const WildBeeHiveReportScreenIT23185302(),
        ),
      );
      return;
    }

    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const MyRequestsScreenIT23185302(),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const BeekeepersDirectoryScreenIT23185302(),
        ),
      );
      return;
    }
  }

  void _onMenuItemTapped(String title) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title will be available in the upcoming update.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.bgSecondary,
          ),
        ),
        backgroundColor: AppColors.panelBlack,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSafetyGuidelinesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: AppColors.warning, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Wild Bee Safety Protocols',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSafetyTip(
                icon: Icons.pan_tool_outlined,
                color: AppColors.warning,
                title: 'Do not disturb or throw objects',
                subtitle:
                    'Wild bees are naturally defensive of their nest. Maintain at least 5 meters distance and avoid sudden movements.',
              ),
              const Divider(height: 20, color: AppColors.border),
              _buildSafetyTip(
                icon: Icons.do_not_touch_outlined,
                color: AppColors.error,
                title: 'Never use toxic insecticide sprays',
                subtitle:
                    'Chemical sprays contaminate the environment, kill crucial pollinators, and make ethical hive relocation impossible.',
              ),
              const Divider(height: 20, color: AppColors.border),
              _buildSafetyTip(
                icon: Icons.pets_outlined,
                color: AppColors.info,
                title: 'Keep pets and young children indoors',
                subtitle:
                    'Pets and children can unwittingly stumble into the colony flight line. Keep them safe inside until a beekeeper arrives.',
              ),
              const Divider(height: 20, color: AppColors.border),
              _buildSafetyTip(
                icon: Icons.support_agent_rounded,
                color: AppColors.success,
                title: 'Request ethical relocation early',
                subtitle:
                    'Promptly report the colony so our verified beekeepers can inspect, plan, and relocate the bees safely without harm.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.panelBlack,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Got It',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.bgSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    Navigator.of(context).pop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log Out',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to log out of Hive Sense?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Log Out',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.bgSecondary,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.instance.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                LoginScreen(inferenceService: widget.inferenceService),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserModel? user = AuthService.instance.currentUser;
    final String initial = (user?.name.isNotEmpty == true)
        ? user!.name[0].toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      drawer: _buildSidebar(user, initial),
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: false,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: AppColors.textPrimary,
              size: 26,
            ),
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Text(
              'Hive Sense',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.badgeLeafBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.badgeLeafFg, width: 0.8),
              ),
              child: Text(
                'WILD BEE',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.badgeLeafFg,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.hiveLow,
              size: 22,
            ),
            tooltip: 'Refresh data',
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.textPrimary,
              size: 22,
            ),
            onPressed: () {},
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
                _buildGreeting(user),
                const SizedBox(height: 20),
                _buildHeroCard(),
                const SizedBox(height: 24),
                _buildSummaryCards(),
                const SizedBox(height: 24),
                _buildLatestRequestBanner(),
                Text(
                  'Quick Actions',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildSafetyGuidelinesSection(),
                const SizedBox(height: 20),
                _buildConservationEducationCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildGreeting(UserModel? user) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final name = user?.name.split(' ').first ?? 'User';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, $name',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Bee Conservation & Relocation Portal',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.badgeLeafBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.badgeLeafFg,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.nature_people_rounded,
                size: 14,
                color: AppColors.badgeLeafFg,
              ),
              const SizedBox(width: 5),
              Text(
                'Normal User',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.badgeLeafFg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.hiveLow.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.panelBlack.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.panelBlack,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Found Bees on Property?',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.panelBlack,
                      ),
                    ),
                    Text(
                      'Report for ethical relocation',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.panelBlack.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Protect both your family and wild bees. Request an assessment to have a local registered beekeeper safely relocate the colony instead of harming it.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.panelBlack.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.panelBlack,
                foregroundColor: AppColors.bgSecondary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_location_alt_rounded, size: 20),
              label: Text(
                'Report Wild Colony',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.bgSecondary,
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WildBeeHiveReportScreenIT23185302(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.assignment_outlined,
            label: 'My Reports',
            value: _loadingStats ? '...' : '$_myReportCount',
            color: AppColors.hiveLow,
            bg: AppColors.badgeBeeBg,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MyRequestsScreenIT23185302(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.verified_user_outlined,
            label: 'Beekeepers',
            value: _loadingStats ? '...' : '$_activeBeekeeperCount',
            color: AppColors.success,
            bg: AppColors.badgeLeafBg,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const BeekeepersDirectoryScreenIT23185302(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.eco_outlined,
            label: 'Relocated',
            value: _loadingStats ? '...' : '$_completedCount',
            color: AppColors.accent3,
            bg: AppColors.badgeLeafBg,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MyRequestsScreenIT23185302(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLatestRequestBanner() {
    if (_myReports.isEmpty) return const SizedBox.shrink();

    final latest = _myReports.first;
    final status = (latest['status'] ?? 'Submitted').toString();
    final location = (latest['location_address'] ?? 'Reported Location').toString();
    final beekeeperName = (latest['beekeeper_name'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hiveLow.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.hiveLow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.hiveLow,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Relocation Progress',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.hiveLow,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.badgeBeeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.hiveLow,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            location,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (beekeeperName.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Assigned: $beekeeperName',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MyRequestsScreenIT23185302(),
                ),
              );
            },
            child: Row(
              children: [
                Text(
                  'View Request Details & Timeline',
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
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.add_location_alt_outlined,
            label: 'Report Colony',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WildBeeHiveReportScreenIT23185302(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.checklist_rtl_rounded,
            label: 'My Requests',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MyRequestsScreenIT23185302(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.groups_outlined,
            label: 'Beekeepers',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const BeekeepersDirectoryScreenIT23185302(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.shield_outlined,
            label: 'Safety Tips',
            onTap: _showSafetyGuidelinesModal,
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyGuidelinesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Wild Bee Safety Guidelines',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: _showSafetyGuidelinesModal,
              child: Text(
                'View All',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.hiveLow,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildSafetyTip(
                icon: Icons.pan_tool_outlined,
                color: AppColors.warning,
                title: 'Do not disturb or throw objects',
                subtitle:
                    'Wild bees are naturally defensive of their nest. Maintain at least 5 meters distance.',
              ),
              const Divider(height: 20, color: AppColors.border),
              _buildSafetyTip(
                icon: Icons.do_not_touch_outlined,
                color: AppColors.error,
                title: 'Avoid chemical insect sprays',
                subtitle:
                    'Pesticides contaminate the ecosystem and make ethical relocation impossible.',
              ),
              const Divider(height: 20, color: AppColors.border),
              _buildSafetyTip(
                icon: Icons.pets_outlined,
                color: AppColors.info,
                title: 'Secure pets and children indoors',
                subtitle:
                    'Ensure animals stay clear of flight paths until the colony is assessed.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConservationEducationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent3.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: AppColors.accent3,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why Save Wild Bees?',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Wild honey bees and native pollinators sustain over 70% of flowering plants and local food crops. Ethical relocation preserves biodiversity while keeping human settlements safe.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyTip({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(UserModel? user, String initial) {
    final String displayName = (user != null && user.name.isNotEmpty)
        ? user.name
        : 'Guest User';
    final String displayEmail = (user != null && user.email.isNotEmpty)
        ? user.email
        : 'Not signed in';

    return Drawer(
      backgroundColor: AppColors.bgSecondary,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: const BoxDecoration(
                gradient: AppColors.accentGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.bgSecondary.withValues(alpha: 0.3),
                          border: Border.all(
                            color: AppColors.bgSecondary,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.panelBlack,
                          child: Text(
                            initial,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.bgPrimary,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textPrimary,
                          size: 22,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayEmail,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Profile',
                    subtitle: 'Personal details and credentials',
                    onTap: () => _onMenuItemTapped('Profile'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.assignment_outlined,
                    title: 'My Relocation Requests',
                    subtitle: 'Track status of reported colonies',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MyRequestsScreenIT23185302(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.groups_outlined,
                    title: 'Beekeepers Directory',
                    subtitle: 'Browse qualified local beekeepers',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const BeekeepersDirectoryScreenIT23185302(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.shield_outlined,
                    title: 'Safety Guidelines',
                    subtitle: 'Protocols for wild colony encounters',
                    onTap: () {
                      Navigator.of(context).pop();
                      _showSafetyGuidelinesModal();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Status updates & alerts',
                    onTap: () => _onMenuItemTapped('Notifications'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    subtitle: 'Conservation guides and FAQ',
                    onTap: () => _onMenuItemTapped('Help & Support'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                  label: Text(
                    'Log Out',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onPressed: _handleLogout,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Hive Sense • Wild Bee Portal v1.0.0',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color iconColor = AppColors.hiveLow,
    Color textColor = AppColors.textPrimary,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
        size: 18,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      onTap: onTap,
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.bgPrimary,
      selectedItemColor: AppColors.hiveLow,
      unselectedItemColor: AppColors.textSecondary,
      showUnselectedLabels: true,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      currentIndex: _currentIndex.clamp(0, 3),
      onTap: _onNavTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_filled),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_location_alt_outlined),
          activeIcon: Icon(Icons.add_location_alt_rounded),
          label: 'Report',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_outlined),
          activeIcon: Icon(Icons.assignment_rounded),
          label: 'Requests',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.groups_outlined),
          activeIcon: Icon(Icons.groups_rounded),
          label: 'Beekeepers',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: AppColors.hiveLow),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
}
