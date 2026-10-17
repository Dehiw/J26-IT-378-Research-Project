import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_model.dart';
import '../models/apiary_model.dart';
import '../services/auth_service.dart';
import '../services/apiary_service.dart';
import '../services/inference_service.dart';
import '../utils/theme.dart';
import 'login_screen.dart';
import 'apiary_management_screen.dart';
import 'relocation_assessment_screen_IT23185302.dart';
import 'wild_bee_hive_report_screen_IT23185302.dart';
import 'my_requests_screen_IT23185302.dart';
import 'beekeepers_directory_screen_IT23185302.dart';

/// Home Page for Hive Sense App.
/// - Left-side hamburger menu / drawer.
/// - Brand title 'Hive Sense'.
/// - Selected Apiary section with dropdown and Manage button.
/// - Summary stat cards, quick actions, hive overview, recent activity.
/// - 5-item bottom navigation bar.
class HomeScreen extends StatefulWidget {
  final InferenceService? inferenceService;

  const HomeScreen({
    super.key,
    this.inferenceService,
  });

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
    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const RelocationAssessmentScreenIT23185302(),
        ),
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  void _onNormalUserNavTapped(int index) {
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
    if (index == 0) {
      setState(() => _currentIndex = 0);
      return;
    }
    final labels = ['Home', 'Report', 'Requests', 'Beekeepers'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${labels[index]} feature will be available in the upcoming update.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.bgSecondary,
          ),
        ),
        backgroundColor: AppColors.panelBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onMenuItemTapped(String title) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title will be available in the next update.',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500,
            color: AppColors.bgSecondary)),
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
        title: Text('Log Out', style: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text('Are you sure you want to log out of Hive Sense?',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error,
              elevation: 0, shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Log Out', style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.bgSecondary)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await AuthService.instance.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) =>
              LoginScreen(inferenceService: widget.inferenceService)),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserModel? user = AuthService.instance.currentUser;
    final bool isNormalUser = user?.isNormalUser ?? false;
    final String initial =
        (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      drawer: _buildSidebar(user, initial),
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: false,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 26),
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text('Hive Sense', style: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.textPrimary, size: 22),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.hiveLow,
          onRefresh: isNormalUser ? () async {} : _loadApiaries,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: isNormalUser
                ? _buildNormalUserBody(user)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      _buildGreeting(user),
                      const SizedBox(height: 20),
                      _buildApiarySelector(),
                      const SizedBox(height: 20),
                      _buildSummaryCards(),
                      const SizedBox(height: 20),
                      Text('Quick Actions', style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      _buildQuickActions(),
                      const SizedBox(height: 20),
                      if (_hives.isNotEmpty) ...[
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Hive Boxes', style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text('${_hives.length} total', style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary)),
                        ]),
                        const SizedBox(height: 12),
                        _buildHiveOverview(),
                        const SizedBox(height: 20),
                      ],
                      Text('Recent Activity', style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      _buildRecentActivity(),
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(isNormalUser),
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
    final isNormalUser = user?.isNormalUser ?? false;

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
              isNormalUser
                  ? 'Bee Conservation & Relocation Portal'
                  : 'Apiary Intelligence Dashboard',
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
            color: isNormalUser ? AppColors.badgeLeafBg : AppColors.badgeBeeBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isNormalUser ? AppColors.badgeLeafFg : AppColors.hiveLow,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNormalUser ? Icons.person_rounded : Icons.hive_rounded,
                size: 13,
                color:
                    isNormalUser ? AppColors.badgeLeafFg : AppColors.hiveLow,
              ),
              const SizedBox(width: 5),
              Text(
                isNormalUser ? 'Normal User' : 'Beekeeper',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      isNormalUser ? AppColors.badgeLeafFg : AppColors.hiveLow,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApiarySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Selected Apiary', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary, letterSpacing: 0.5)),
            GestureDetector(
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ApiaryManagementScreen()));
                _loadApiaries();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Manage', style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.panelBlack)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.location_on_rounded, color: AppColors.hiveLow, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: _loadingApiaries
                ? Container(height: 16, decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(8)))
                : _apiaries.isEmpty
                    ? Text('No apiary added yet', style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textMuted))
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<ApiaryModel>(
                          value: _selectedApiary,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textSecondary, size: 18),
                          style: GoogleFonts.inter(fontSize: 15,
                              fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          dropdownColor: AppColors.bgSecondary,
                          items: _apiaries.map((a) => DropdownMenuItem(
                            value: a,
                            child: Text(a.locationName,
                              style: GoogleFonts.inter(fontSize: 15,
                                  fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (apiary) async {
                            if (apiary == null) return;
                            await ApiaryService.instance.selectApiary(apiary);
                            setState(() { _selectedApiary = apiary; _hives = []; });
                            _loadHives(apiary.id);
                          },
                        ),
                      ),
          ),
        ]),
        if (_selectedApiary != null) ...[
          const SizedBox(height: 6),
          Text(_selectedApiary!.areaAddress, style: GoogleFonts.inter(
            fontSize: 12, color: AppColors.textSecondary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }

  Widget _buildSummaryCards() {
    final totalHives = _selectedApiary?.totalHives ?? 0;
    final totalFrames = _selectedApiary?.totalFrames ?? 0;
    final healthyHives = _hives.where((h) => h.status == 'Healthy').length;
    return Row(children: [
      Expanded(child: _StatCard(icon: Icons.hive_outlined, label: 'Hive Boxes',
          value: '$totalHives', color: AppColors.hiveLow, bg: AppColors.badgeBeeBg)),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(icon: Icons.grid_view_rounded, label: 'Frames',
          value: '$totalFrames', color: AppColors.accent3, bg: AppColors.badgeLeafBg)),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(icon: Icons.favorite_rounded, label: 'Healthy',
          value: totalHives == 0 ? '-' : '$healthyHives/$totalHives',
          color: AppColors.success, bg: AppColors.badgeLeafBg)),
    ]);
  }

  Widget _buildQuickActions() {
    return Row(children: [
      Expanded(child: _QuickAction(icon: Icons.add_box_outlined, label: 'Add Hive',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ApiaryManagementScreen())))),
      const SizedBox(width: 10),
      Expanded(child: _QuickAction(icon: Icons.bar_chart_rounded, label: 'Inspect', onTap: () {})),
      const SizedBox(width: 10),
      Expanded(child: _QuickAction(icon: Icons.notifications_active_outlined,
          label: 'Alerts', onTap: () {})),
      const SizedBox(width: 10),
      Expanded(child: _QuickAction(icon: Icons.share_outlined, label: 'Report', onTap: () {})),
    ]);
  }

  Widget _buildHiveOverview() {
    final visible = _hives.take(3).toList();
    return Column(children: [
      ...visible.map((h) => _HiveRow(hive: h)),
      if (_hives.length > 3)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ApiaryManagementScreen())),
            child: Text('+${_hives.length - 3} more hive boxes',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.hiveLow, decoration: TextDecoration.underline,
                decorationColor: AppColors.hiveLow),
              textAlign: TextAlign.center),
          ),
        ),
    ]);
  }

  Widget _buildRecentActivity() {
    final items = [
      _ActivityItem(icon: Icons.sensors_rounded, title: 'Sensor data synced',
          subtitle: 'All hives reported — 2 min ago', color: AppColors.info),
      _ActivityItem(icon: Icons.thermostat_rounded, title: 'Temperature normal',
          subtitle: 'Hive Box #01 — 35°C — 15 min ago', color: AppColors.success),
      _ActivityItem(icon: Icons.volume_up_outlined, title: 'Acoustic scan complete',
          subtitle: 'No abnormal patterns detected', color: AppColors.accent3),
    ];
    return Container(
      decoration: BoxDecoration(color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border)),
      child: Column(
        children: List.generate(items.length, (i) => Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: items[i].color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(items[i].icon, size: 18, color: items[i].color)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(items[i].title, style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(items[i].subtitle, style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textSecondary)),
                ])),
            ]),
          ),
          if (i < items.length - 1)
            const Divider(height: 1, color: AppColors.border, indent: 64),
        ])),
      ),
    );
  }

  Widget _buildSidebar(UserModel? user, String initial) {
    final String displayName =
        (user != null && user.name.isNotEmpty) ? user.name : 'Guest User';
    final String displayEmail =
        (user != null && user.email.isNotEmpty) ? user.email : 'Not signed in';
    return Drawer(
      backgroundColor: AppColors.bgSecondary,
      child: SafeArea(
        top: false,
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(gradient: AppColors.accentGradient),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: AppColors.bgSecondary.withValues(alpha: 0.3),
                    border: Border.all(color: AppColors.bgSecondary, width: 2)),
                  child: CircleAvatar(radius: 26,
                    backgroundColor: AppColors.panelBlack,
                    child: Text(initial, style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.bgPrimary))),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary, size: 22),
                  onPressed: () => Navigator.of(context).pop()),
              ]),
              const SizedBox(height: 14),
              Text(displayName, style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(displayEmail, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: AppColors.textPrimary.withValues(alpha: 0.8)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Expanded(child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildDrawerItem(icon: Icons.person_outline_rounded, title: 'Profile',
                subtitle: 'Personal details and credentials',
                onTap: () => _onMenuItemTapped('Profile')),
              _buildDrawerItem(icon: Icons.settings_outlined, title: 'Settings',
                subtitle: 'Preferences and configurations',
                onTap: () => _onMenuItemTapped('Settings')),
              _buildDrawerItem(icon: Icons.notifications_outlined,
                title: 'Notification Settings',
                subtitle: 'Alerts, thresholds and push notices',
                onTap: () => _onMenuItemTapped('Notification Settings')),
              _buildDrawerItem(icon: Icons.help_outline_rounded, title: 'Help & Support',
                subtitle: 'Guides, documentation and contact',
                onTap: () => _onMenuItemTapped('Help & Support')),
            ],
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(width: double.infinity, height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.logout_rounded, color: AppColors.textPrimary, size: 18),
                label: Text('Log Out', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                onPressed: _handleLogout,
              )),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Hive Sense • v1.0.0', style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
          ),
        ]),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon, required String title,
    String? subtitle, required VoidCallback onTap,
    Color iconColor = AppColors.hiveLow, Color textColor = AppColors.textPrimary,
  }) {
    return ListTile(
      leading: Container(width: 38, height: 38,
        decoration: BoxDecoration(color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 20)),
      title: Text(title, style: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
      subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.inter(
        fontSize: 11, color: AppColors.textSecondary)) : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      onTap: onTap,
    );
  }

  Widget _buildBottomNav(bool isNormalUser) {
    if (isNormalUser) {
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.bgPrimary,
        selectedItemColor: AppColors.hiveLow,
        unselectedItemColor: AppColors.textSecondary,
        showUnselectedLabels: true,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        currentIndex: _currentIndex.clamp(0, 3),
        onTap: _onNormalUserNavTapped,
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

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.bgPrimary,
      selectedItemColor: AppColors.hiveLow,
      unselectedItemColor: AppColors.textSecondary,
      showUnselectedLabels: true,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      currentIndex: _currentIndex.clamp(0, 4),
      onTap: _onNavTapped,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.monitor_heart_outlined), label: 'Health'),
        BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), label: 'Relocate'),
        BottomNavigationBarItem(icon: Icon(Icons.graphic_eq_rounded), label: 'Acoustic'),
        BottomNavigationBarItem(icon: Icon(Icons.eco_outlined), label: 'Environment'),
      ],
    );
  }

  Widget _buildNormalUserBody(UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _buildGreeting(user),
        const SizedBox(height: 20),

        // Hero Card: Report Wild Bee Colony
        Container(
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
                'Protect both your family and wild bees. Request an assessment to have a local beekeeper safely relocate the colony instead of harming it.',
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
                        builder: (_) =>
                            const WildBeeHiveReportScreenIT23185302(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Quick Stats / Overview
        const Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.assignment_outlined,
                label: 'My Reports',
                value: '0',
                color: AppColors.hiveLow,
                bg: AppColors.badgeBeeBg,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.verified_user_outlined,
                label: 'Beekeepers',
                value: '12 Active',
                color: AppColors.success,
                bg: AppColors.badgeLeafBg,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.eco_outlined,
                label: 'Colonies Saved',
                value: '100%',
                color: AppColors.accent3,
                bg: AppColors.badgeLeafBg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Text(
          'Quick Actions',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.add_location_alt_outlined,
                label: 'Report Colony',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const WildBeeHiveReportScreenIT23185302(),
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
                onTap: () => _onMenuItemTapped('Bee Safety Tips'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Text(
          'Wild Bee Safety Guidelines',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
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
                    'Pesticides contaminate the ecosystem and make relocation impossible.',
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
        const SizedBox(height: 32),
      ],
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
}

// ── Supporting sub-widgets ─────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _StatCard({required this.icon, required this.label,
      required this.value, required this.color, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 17, color: color)),
      const SizedBox(height: 10),
      Text(value, style: GoogleFonts.inter(
        fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
    ]),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Icon(icon, size: 22, color: AppColors.hiveLow),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ]),
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
    decoration: BoxDecoration(color: AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(
          '#${hive.boxNumber.toString().padLeft(2, '0')}',
          style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.hiveLow)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(hive.name, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text('${hive.numFrames} frames',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: hive.status == 'Healthy' ? AppColors.badgeLeafBg : AppColors.badgeTempBg,
          borderRadius: BorderRadius.circular(8)),
        child: Text(hive.status, style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: hive.status == 'Healthy' ? AppColors.success : AppColors.error)),
      ),
    ]),
  );
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _ActivityItem({required this.icon, required this.title,
      required this.subtitle, required this.color});
}
