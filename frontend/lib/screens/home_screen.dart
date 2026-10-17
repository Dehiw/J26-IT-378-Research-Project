import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_model.dart';
import '../models/apiary_model.dart';
import '../services/auth_service.dart';
import '../services/apiary_service.dart';
import '../services/inference_service.dart';
import '../utils/theme.dart';
import '../widgets/main_bottom_nav.dart';
import 'login_screen.dart';
import 'apiary_management_screen.dart';
import 'IT23183186_environment_dashboard_screen.dart';
import 'IT23183186_disease_check_screen.dart';
import 'IT23183186_forage_map_screen.dart';
import 'IT23183186_hive_telemetry_screen.dart';

/// Home Page for Hive Sense App.
/// - Left-side hamburger menu / drawer.
/// - Brand title 'Hive Sense'.
/// - Selected Apiary section with dropdown and Manage button.
/// - Summary stat cards, quick actions, hive overview, recent activity.
/// - 5-item bottom navigation bar.
class HomeScreen extends StatefulWidget {
  final InferenceService? inferenceService;

  const HomeScreen({super.key, this.inferenceService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Apiary data
  List<ApiaryModel> _apiaries = [];
  ApiaryModel? _selectedApiary;
  List<HiveModel> _hives = [];
  bool _loadingApiaries = true;

  @override
  void initState() {
    super.initState();
    _loadApiaries();
  }

  Future<void> _loadApiaries() async {
    setState(() => _loadingApiaries = true);
    try {
      final list = await ApiaryService.instance.fetchApiaries();
      final selected = ApiaryService.instance.selectedApiary;
      if (mounted) {
        setState(() {
          _apiaries = list;
          _selectedApiary = selected ?? (list.isNotEmpty ? list.first : null);
          _loadingApiaries = false;
        });
        if (_selectedApiary != null) _loadHives(_selectedApiary!.id);
      }
    } catch (e) {
      developer.log('Load apiaries error: $e', name: 'HomeScreen');
      if (mounted) setState(() => _loadingApiaries = false);
    }
  }

  Future<void> _loadHives(String apiaryId) async {
    try {
      final hives = await ApiaryService.instance.fetchHives(apiaryId);
      if (mounted) setState(() => _hives = hives);
    } catch (e) {
      developer.log('Load hives error: $e', name: 'HomeScreen');
    }
  }

  void _onNavTapped(int index) {
    if (index == 0) return;
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const DiseaseCheckScreen()),
      );
    } else if (index == 2) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ForageMapScreen()));
    } else if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const EnvironmentDashboardScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Acoustic monitoring is coming soon.',
            style: GoogleFonts.inter(color: AppColors.bgSecondary),
          ),
          backgroundColor: AppColors.panelBlack,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onMenuItemTapped(String title) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title will be available in the next update.',
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
        : 'B';

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
        title: Text(
          'Hive Sense',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
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
          onRefresh: _loadApiaries,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _buildGreeting(user),
                const SizedBox(height: 20),
                _buildApiarySelector(),
                const SizedBox(height: 20),
                _buildSummaryCards(),
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                if (_hives.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hive Boxes',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_hives.length} total',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildHiveOverview(),
                  const SizedBox(height: 20),
                ],
                Text(
                  'Recent Activity',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
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

  Widget _buildGreeting(UserModel? user) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';
    final name = user?.name.split(' ').first ?? 'Beekeeper';
    return Text(
      '$greeting, $name',
      style: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildApiarySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Apiary',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ApiaryManagementScreen(),
                    ),
                  );
                  _loadApiaries();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Manage',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.panelBlack,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AppColors.hiveLow,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _loadingApiaries
                    ? Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )
                    : _apiaries.isEmpty
                    ? Text(
                        'No apiary added yet',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<ApiaryModel>(
                          value: _selectedApiary,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          dropdownColor: AppColors.bgSecondary,
                          items: _apiaries
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(
                                    a.locationName,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (apiary) async {
                            if (apiary == null) return;
                            await ApiaryService.instance.selectApiary(apiary);
                            setState(() {
                              _selectedApiary = apiary;
                              _hives = [];
                            });
                            _loadHives(apiary.id);
                          },
                        ),
                      ),
              ),
            ],
          ),
          if (_selectedApiary != null) ...[
            const SizedBox(height: 6),
            Text(
              _selectedApiary!.areaAddress,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalHives = _selectedApiary?.totalHives ?? 0;
    final totalFrames = _selectedApiary?.totalFrames ?? 0;
    final healthyHives = _hives.where((h) => h.status == 'Healthy').length;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.hive_outlined,
            label: 'Hive Boxes',
            value: '$totalHives',
            color: AppColors.hiveLow,
            bg: AppColors.badgeBeeBg,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.grid_view_rounded,
            label: 'Frames',
            value: '$totalFrames',
            color: AppColors.accent3,
            bg: AppColors.badgeLeafBg,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.favorite_rounded,
            label: 'Healthy',
            value: totalHives == 0 ? '-' : '$healthyHives/$totalHives',
            color: AppColors.success,
            bg: AppColors.badgeLeafBg,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.add_box_outlined,
            label: 'Add Hive',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ApiaryManagementScreen()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.bar_chart_rounded,
            label: 'Inspect',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.notifications_active_outlined,
            label: 'Alerts',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.share_outlined,
            label: 'Report',
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildHiveOverview() {
    final visible = _hives.take(3).toList();
    return Column(
      children: [
        ...visible.map((h) => _HiveRow(hive: h)),
        if (_hives.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ApiaryManagementScreen(),
                ),
              ),
              child: Text(
                '+${_hives.length - 3} more hive boxes',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.hiveLow,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.hiveLow,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final items = [
      _ActivityItem(
        icon: Icons.sensors_rounded,
        title: 'Sensor data synced',
        subtitle: 'All hives reported â€” 2 min ago',
        color: AppColors.info,
      ),
      _ActivityItem(
        icon: Icons.thermostat_rounded,
        title: 'Temperature normal',
        subtitle: 'Hive Box #01 â€” 35Â°C â€” 15 min ago',
        color: AppColors.success,
      ),
      _ActivityItem(
        icon: Icons.volume_up_outlined,
        title: 'Acoustic scan complete',
        subtitle: 'No abnormal patterns detected',
        color: AppColors.accent3,
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(
          items.length,
          (i) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: items[i].color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        items[i].icon,
                        size: 18,
                        color: items[i].color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1)
                const Divider(height: 1, color: AppColors.border, indent: 64),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(UserModel? user, String initial) {
    final String displayName = user?.name ?? 'Beekeeper';
    final String displayEmail = user?.email ?? 'beekeeper@hivesense.org';
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
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Preferences and configurations',
                    onTap: () => _onMenuItemTapped('Settings'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notification Settings',
                    subtitle: 'Alerts, thresholds and push notices',
                    onTap: () => _onMenuItemTapped('Notification Settings'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    subtitle: 'Guides, documentation and contact',
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
                'Hive Sense â€¢ v1.0.0',
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
    return MainBottomNav(currentIndex: _currentIndex, onTap: _onNavTapped);
  }
}

// â”€â”€ Supporting sub-widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
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

class _HiveRow extends StatelessWidget {
  final HiveModel hive;
  const _HiveRow({required this.hive});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '#${hive.boxNumber.toString().padLeft(2, '0')}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.hiveLow,
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
                hive.name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${hive.numFrames} frames',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: hive.status == 'Healthy'
                ? AppColors.badgeLeafBg
                : AppColors.badgeTempBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            hive.status,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: hive.status == 'Healthy'
                  ? AppColors.success
                  : AppColors.error,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}
