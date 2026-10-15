import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/apiary_model.dart';
import '../services/apiary_service.dart';
import '../services/inference_service.dart';
import '../utils/theme.dart';
import '../widgets/wooden_hive_box.dart';
import '../widgets/bee_illustration.dart';
import 'add_hive_screen.dart';
import 'apiary_management_screen.dart';
import 'scanner_screen.dart';

/// Colony Health Monitoring Screen
/// Displays the active apiary selector, "+ Add Hive" action,
/// and the list of hives with live health status, matching the reference design.
class HealthScreen extends StatefulWidget {
  final InferenceService? inferenceService;

  const HealthScreen({
    super.key,
    this.inferenceService,
  });

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  static const int _tabIndex = 1;

  List<ApiaryModel> _apiaries = [];
  ApiaryModel? _selectedApiary;
  List<_HiveHealthItem> _hiveItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final list = await ApiaryService.instance.fetchApiaries();
      final selected = ApiaryService.instance.selectedApiary;
      if (mounted) {
        setState(() {
          _apiaries = list;
          _selectedApiary = selected ?? (list.isNotEmpty ? list.first : null);
        });

        if (_selectedApiary != null) {
          await _loadHivesForApiary(_selectedApiary!.id);
        } else {
          _useMockHiveItems();
        }
      }
    } catch (e) {
      developer.log('Failed to load apiaries: $e', name: 'HealthScreen');
      if (mounted) {
        _useMockHiveItems();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadHivesForApiary(String apiaryId) async {
    try {
      final realHives = await ApiaryService.instance.fetchHives(apiaryId);
      if (mounted) {
        if (realHives.isNotEmpty) {
          setState(() {
            _hiveItems = realHives.map((h) {
              final isHealthy = h.status.toLowerCase() == 'healthy';
              return _HiveHealthItem(
                id: h.id,
                name: h.name,
                boxNumber: h.boxNumber,
                status: isHealthy ? 'Healthy' : 'Attention',
                isHealthy: isHealthy,
                lastUpdated: 'Last updated: ${h.boxNumber * 2} min ago',
                numFrames: h.numFrames,
                hiveModel: h,
              );
            }).toList();
          });
        } else {
          // If no hives yet for this apiary, show default reference preview
          _useMockHiveItems();
        }
      }
    } catch (e) {
      developer.log('Load hives error: $e', name: 'HealthScreen');
      if (mounted) _useMockHiveItems();
    }
  }

  void _useMockHiveItems() {
    _hiveItems = [
      const _HiveHealthItem(
        id: 'mock-1',
        name: 'Hive 01',
        boxNumber: 1,
        status: 'Healthy',
        isHealthy: true,
        lastUpdated: 'Last updated: 2 min ago',
        numFrames: 10,
      ),
      const _HiveHealthItem(
        id: 'mock-2',
        name: 'Hive 02',
        boxNumber: 2,
        status: 'Attention',
        isHealthy: false,
        lastUpdated: 'Last updated: 5 min ago',
        numFrames: 8,
      ),
      const _HiveHealthItem(
        id: 'mock-3',
        name: 'Hive 03',
        boxNumber: 3,
        status: 'Healthy',
        isHealthy: true,
        lastUpdated: 'Last updated: 3 min ago',
        numFrames: 10,
      ),
      const _HiveHealthItem(
        id: 'mock-4',
        name: 'Hive 04',
        boxNumber: 4,
        status: 'Healthy',
        isHealthy: true,
        lastUpdated: 'Last updated: 6 min ago',
        numFrames: 9,
      ),
    ];
  }

  void _onNavTapped(int index) {
    if (index == _tabIndex) return;
    if (index == 0) {
      // Return to Home
      Navigator.of(context).pop();
      return;
    }

    final labels = ['Home', 'Health', 'Relocate', 'Acoustic', 'Environment'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${labels[index]} module will be available in the next update.',
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

  void _openAddHive() async {
    ApiaryModel? targetApiary = _selectedApiary;

    // If no real apiary exists yet, prompt user or open ApiaryManagementScreen
    if (targetApiary == null) {
      if (_apiaries.isNotEmpty) {
        targetApiary = _apiaries.first;
      } else {
        final created = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const ApiaryManagementScreen()),
        );
        if (created == true) _loadData();
        return;
      }
    }

    final result = await Navigator.of(context).push<HiveModel>(
      MaterialPageRoute(
        builder: (_) => AddHiveScreen(apiary: targetApiary!),
      ),
    );

    if (result != null) {
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.darkGreen,
            behavior: SnackBarBehavior.floating,
            content: Text(
              '${result.name} added to ${targetApiary.locationName}!',
              style: GoogleFonts.inter(color: AppColors.bgSecondary),
            ),
          ),
        );
      }
    }
  }

  void _showApiaryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Apiary',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ApiaryManagementScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                      icon: const Icon(Icons.settings_outlined, size: 16, color: AppColors.darkGreen),
                      label: Text(
                        'Manage',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_apiaries.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Using default demo apiary (Yakkala Apiary)',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ] else ...[
                  ..._apiaries.map((apiary) {
                    final isSelected = _selectedApiary?.id == apiary.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.lightGreenCard : AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppColors.darkGreen : AppColors.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await ApiaryService.instance.selectApiary(apiary);
                          setState(() => _selectedApiary = apiary);
                          _loadHivesForApiary(apiary.id);
                        },
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.darkGreen : AppColors.bgElevated,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 18,
                            color: isSelected ? AppColors.bgSecondary : AppColors.darkGreen,
                          ),
                        ),
                        title: Text(
                          apiary.locationName,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${apiary.totalHives} Hive Boxes • ${apiary.areaAddress}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.darkGreen, size: 20)
                            : null,
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _onHiveTapped(_HiveHealthItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _HiveDetailSheet(
        item: item,
        inferenceService: widget.inferenceService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiaryName = _selectedApiary?.locationName ?? 'Yakkala Apiary';
    final hiveCount = _selectedApiary?.totalHives ?? _hiveItems.length;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.darkGreen,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // 1. Header with Title and Bee Illustration
                _buildHeader(),
                const SizedBox(height: 20),
                // 2. Apiary Selector Card
                _buildApiaryCard(apiaryName, hiveCount),
                const SizedBox(height: 24),
                // 3. Section Title + Add Hive Button
                _buildSectionHeader(),
                const SizedBox(height: 14),
                // 4. Hive List Cards
                ..._hiveItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final hive = entry.value;
                  return _HiveCard(
                    item: hive,
                    onTap: () => _onHiveTapped(hive),
                  )
                      .animate()
                      .fadeIn(delay: (60 * index).ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
                }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Header ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Colony Health\nMonitoring',
                style: GoogleFonts.inter(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const BeeIllustration(size: 80),
      ],
    );
  }

  // ── Apiary Selector Card ──────────────────────────────────────────
  Widget _buildApiaryCard(String name, int hiveCount) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showApiaryPicker,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Circular green badge with location pin
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.darkGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.bgSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Name and count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$hiveCount Hive Boxes',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Dropdown chevron
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section Header ────────────────────────────────────────────────
  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Hives',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _openAddHive,
          icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.bgSecondary),
          label: Text(
            'Add Hive',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.bgSecondary,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkGreen,
            foregroundColor: AppColors.bgSecondary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: const StadiumBorder(),
          ),
        ),
      ],
    );
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
      currentIndex: _tabIndex,
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

// ── Hive Health Data Model ──────────────────────────────────────────
class _HiveHealthItem {
  final String id;
  final String name;
  final int boxNumber;
  final String status;
  final bool isHealthy;
  final String lastUpdated;
  final int numFrames;
  final HiveModel? hiveModel;

  const _HiveHealthItem({
    required this.id,
    required this.name,
    required this.boxNumber,
    required this.status,
    required this.isHealthy,
    required this.lastUpdated,
    required this.numFrames,
    this.hiveModel,
  });
}

// ── Hive Card Widget ────────────────────────────────────────────────
class _HiveCard extends StatelessWidget {
  final _HiveHealthItem item;
  final VoidCallback onTap;

  const _HiveCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // 3D Wooden Hive Box art
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const WoodenHiveBox(size: 52),
                ),
                const SizedBox(width: 14),
                // Title, Status dot + text, and Last updated
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (item.isHealthy) ...[
                            // Green circle dot
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Healthy',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ] else ...[
                            // Amber droplet / attention icon
                            const Icon(
                              Icons.water_drop_rounded,
                              size: 13,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Attention',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.lastUpdated,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Chevron right
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hive Detail / Inspection Modal ──────────────────────────────────
class _HiveDetailSheet extends StatelessWidget {
  final _HiveHealthItem item;
  final InferenceService? inferenceService;

  const _HiveDetailSheet({
    required this.item,
    this.inferenceService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 16),
            Row(
              children: [
                const WoodenHiveBox(size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.numFrames} Frames • ${item.lastUpdated}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: item.isHealthy ? AppColors.badgeLeafBg : AppColors.badgeTempBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.status,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: item.isHealthy ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Health Metric highlights
            Row(
              children: [
                Expanded(
                  child: _MetricBadge(
                    label: 'Status',
                    value: item.isHealthy ? 'Optimal' : 'Needs Check',
                    icon: Icons.monitor_heart_outlined,
                    color: item.isHealthy ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: _MetricBadge(
                    label: 'Brood Temp',
                    value: '35.2 °C',
                    icon: Icons.thermostat_outlined,
                    color: AppColors.hiveLow,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: _MetricBadge(
                    label: 'Humidity',
                    value: '58%',
                    icon: Icons.water_drop_outlined,
                    color: AppColors.accent3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Scan / Inspect Action Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ScannerScreen(inferenceService: inferenceService),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt_outlined, size: 20, color: AppColors.bgSecondary),
              label: Text(
                'Start Health Inspection Scan',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.bgSecondary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkGreen,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
