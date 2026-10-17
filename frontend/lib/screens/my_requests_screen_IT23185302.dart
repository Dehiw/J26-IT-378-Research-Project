import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/wild_bee_service.dart';
import '../utils/theme.dart';
import 'home_screen.dart';
import 'wild_bee_hive_report_screen_IT23185302.dart';
import 'beekeepers_directory_screen_IT23185302.dart';

/// Research Component IT23185302:
/// My Requests Page & Relocation Tracking Workflow for Normal Users.
class MyRequestsScreenIT23185302 extends StatefulWidget {
  const MyRequestsScreenIT23185302({super.key});

  @override
  State<MyRequestsScreenIT23185302> createState() =>
      _MyRequestsScreenIT23185302State();
}

class _MyRequestsScreenIT23185302State extends State<MyRequestsScreenIT23185302> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  String _selectedFilter = 'All'; // 'All', 'Active', 'Completed', 'Cancelled'

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fetched = await WildBeeService.instance.fetchMyReports();

      // If database has reports, use them; otherwise add standard demo items
      // including the user-specified example (#R012, Yakkala, Accepted)
      if (fetched.isNotEmpty) {
        _reports = fetched;
      } else {
        _reports = _getSampleDemonstrationReports();
      }
    } catch (e) {
      developer.log('Notice loading reports: $e', name: 'MyRequestsScreen');
      _reports = _getSampleDemonstrationReports();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Default demonstration requests covering various pipeline statuses
  List<Map<String, dynamic>> _getSampleDemonstrationReports() {
    return [
      {
        'id': 'REL-2026-R012',
        'display_id': '#R012',
        'address': 'Yakkala, Gampaha District',
        'created_at': '2026-10-18T09:30:00Z',
        'status': 'Accepted',
        'colony_location': 'Roof',
        'height': '2–5 m',
        'inside_structure': 'Yes',
        'safe_access': 'Yes',
        'assigned_beekeeper': 'Nimal Senanayake',
        'assigned_phone': '+94 77 412 8990',
        'beekeeper_role': 'Certified Master Apiarist (12+ Yrs)',
        'has_photo': false,
        'notes': 'Colony settled in attic roof beam near rain gutter.',
      },
      {
        'id': 'REL-2026-R018',
        'display_id': '#R018',
        'address': '42 Flower Road, Colombo 07',
        'created_at': '2026-10-17T14:15:00Z',
        'status': 'Under Review',
        'colony_location': 'Tree',
        'height': 'Below 2 m',
        'inside_structure': 'No',
        'safe_access': 'Yes',
        'assigned_beekeeper': null,
        'has_photo': false,
        'notes': 'Gentle swarm on low mango tree branch.',
      },
      {
        'id': 'REL-2026-R007',
        'display_id': '#R007',
        'address': 'Kandy Road, Kadawatha',
        'created_at': '2026-10-15T11:00:00Z',
        'status': 'Completed',
        'colony_location': 'Wall',
        'height': '2–5 m',
        'inside_structure': 'Yes',
        'safe_access': 'Yes',
        'assigned_beekeeper': 'Chaminda Silva',
        'assigned_phone': '+94 71 884 1209',
        'beekeeper_role': 'Urban Bee Rescuer',
        'has_photo': false,
        'notes': 'Successfully transferred to smart hive box and moved to Hanwella apiary.',
      },
    ];
  }

  List<Map<String, dynamic>> get _filteredReports {
    if (_selectedFilter == 'All') return _reports;
    if (_selectedFilter == 'Active') {
      return _reports.where((r) {
        final s = r['status']?.toString() ?? 'Submitted';
        return s != 'Completed' && s != 'Cancelled';
      }).toList();
    }
    if (_selectedFilter == 'Completed') {
      return _reports
          .where((r) => r['status']?.toString() == 'Completed')
          .toList();
    }
    if (_selectedFilter == 'Cancelled') {
      return _reports
          .where((r) => r['status']?.toString() == 'Cancelled')
          .toList();
    }
    return _reports;
  }

  // ── Status Color & Icon Utility ─────────────────────────────
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Submitted':
        return AppColors.info;
      case 'Under Review':
        return AppColors.warning;
      case 'Waiting for Beekeeper':
        return AppColors.hiveLow;
      case 'Accepted':
        return AppColors.success;
      case 'Relocation Scheduled':
        return AppColors.accent2;
      case 'In Progress':
        return AppColors.warning;
      case 'Completed':
        return AppColors.success;
      case 'Cancelled':
        return AppColors.error;
      default:
        return AppColors.hiveLow;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Submitted':
        return Icons.send_rounded;
      case 'Under Review':
        return Icons.search_rounded;
      case 'Waiting for Beekeeper':
        return Icons.hourglass_top_rounded;
      case 'Accepted':
        return Icons.verified_user_rounded;
      case 'Relocation Scheduled':
        return Icons.event_available_rounded;
      case 'In Progress':
        return Icons.sync_rounded;
      case 'Completed':
        return Icons.check_circle_rounded;
      case 'Cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoString.length >= 10 ? isoString.substring(0, 10) : 'Recent';
    }
  }

  // ── Bottom Nav Navigation ───────────────────────────────────
  void _onNavTapped(int index) {
    if (index == 2) return; // Already on Requests

    if (index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    if (index == 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const WildBeeHiveReportScreenIT23185302(),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const BeekeepersDirectoryScreenIT23185302(),
        ),
      );
      return;
    }
  }

  // ── Open View Details Modal ─────────────────────────────────
  void _openDetailsModal(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestDetailsSheet(
        report: report,
        onReportCancelled: () {
          _loadReports();
        },
        onSelectBeekeeperTapped: () {
          _openSelectBeekeeperSheet(report);
        },
      ),
    );
  }

  // ── Select Beekeeper According to Location Sheet ────────────
  void _openSelectBeekeeperSheet(Map<String, dynamic> report) {
    final reportId = report['id']?.toString() ?? '';
    final reportAddress =
        (report['address'] ?? 'Sri Lanka').toString().toLowerCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Beekeeper',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'According to location: ${report['display_id'] ?? reportId}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 18, color: AppColors.border),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.hiveLow.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 16, color: AppColors.accent2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hive Location: ${report['address'] ?? 'Sri Lanka'}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: AuthService.instance.fetchRegisteredBeekeepers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(AppColors.hiveLow),
                        ),
                      );
                    }
                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.groups_outlined,
                                size: 36, color: AppColors.textSecondary),
                            const SizedBox(height: 8),
                            Text(
                              'No registered beekeepers in database yet.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Sort matching location first
                    final sorted = List<Map<String, dynamic>>.from(list);
                    sorted.sort((a, b) {
                      final aArea =
                          (a['area_address'] ?? '').toString().toLowerCase();
                      final bArea =
                          (b['area_address'] ?? '').toString().toLowerCase();
                      final aMatch = reportAddress.isNotEmpty &&
                          reportAddress.contains(aArea);
                      final bMatch = reportAddress.isNotEmpty &&
                          reportAddress.contains(bArea);
                      if (aMatch && !bMatch) return -1;
                      if (!aMatch && bMatch) return 1;
                      return 0;
                    });

                    return ListView.separated(
                      itemCount: sorted.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final bk = sorted[i];
                        final name = (bk['name'] ?? 'Beekeeper').toString();
                        final apiary =
                            (bk['apiary_name'] ?? 'Registered Apiary')
                                .toString();
                        final area =
                            (bk['area_address'] ?? 'Sri Lanka').toString();
                        final phone = (bk['phone'] ?? '').toString();
                        final aArea = area.toLowerCase();
                        final isMatch = reportAddress.isNotEmpty &&
                            (reportAddress.contains(aArea) ||
                                aArea.contains(reportAddress) ||
                                (aArea.contains('gampaha') &&
                                    reportAddress.contains('gampaha')) ||
                                (aArea.contains('colombo') &&
                                    reportAddress.contains('colombo')) ||
                                (aArea.contains('kandy') &&
                                    reportAddress.contains('kandy')));

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isMatch
                                  ? AppColors.hiveLow
                                  : AppColors.border,
                              width: isMatch ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    AppColors.hiveLow.withValues(alpha: 0.15),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'B',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.hiveLow,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isMatch) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: AppColors.success
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              'Nearby Area',
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$apiary • $area',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (phone.isNotEmpty)
                                      Text(
                                        phone,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.hiveLow,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.hiveLow,
                                  foregroundColor: AppColors.bgSecondary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    await WildBeeService.instance
                                        .assignBeekeeper(
                                      reportId: reportId,
                                      beekeeperName: name,
                                      beekeeperPhone: phone,
                                      beekeeperId:
                                          (bk['id'] ?? '').toString(),
                                    );
                                    _loadReports();
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Assigned $name according to location!',
                                            style: GoogleFonts.inter(
                                              color: AppColors.bgSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          backgroundColor: AppColors.success,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Failed to assign: $e'),
                                          backgroundColor: AppColors.error,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Text(
                                  'Assign',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'My Relocation Requests',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.hiveLow),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.hiveLow,
          backgroundColor: AppColors.bgSecondary,
          onRefresh: _loadReports,
          child: Column(
            children: [
              // ── Filter Chips ──────────────────────────────────────
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip('All'),
                    _buildFilterChip('Active'),
                    _buildFilterChip('Completed'),
                    _buildFilterChip('Cancelled'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Requests List / Content ───────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.hiveLow,
                          ),
                        ),
                      )
                    : _filteredReports.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            itemCount: _filteredReports.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, i) {
                              return _buildRequestCard(_filteredReports[i]);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.bgPrimary,
        selectedItemColor: AppColors.hiveLow,
        unselectedItemColor: AppColors.textSecondary,
        showUnselectedLabels: true,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        currentIndex: 2, // Requests is selected
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
      ),
    );
  }

  // ── Filter Chip Widget ──────────────────────────────────────
  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = label),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppColors.bgSecondary : AppColors.textPrimary,
        ),
        selectedColor: AppColors.hiveLow,
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppColors.hiveLow : AppColors.border,
          ),
        ),
      ),
    );
  }

  // ── Single Request Card ─────────────────────────────────────
  Widget _buildRequestCard(Map<String, dynamic> report) {
    final rawId = report['id']?.toString() ?? 'REL-2026';
    final displayId = report['display_id']?.toString() ??
        (rawId.length >= 8 ? '#${rawId.substring(rawId.length - 4)}' : rawId);
    final location = report['address']?.toString() ?? 'Sri Lanka';
    final status = report['status']?.toString() ?? 'Submitted';
    final dateDisplay = _formatDate(report['created_at']?.toString());
    final beekeeper = report['assigned_beekeeper']?.toString();
    final hasPhoto = report['has_photo'] == true ||
        (report['photo_url'] != null &&
            report['photo_url'].toString().isNotEmpty);
    final photoUrl = report['photo_url']?.toString();

    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hive photo thumbnail
                _buildThumbnail(hasPhoto, photoUrl),
                const SizedBox(width: 14),

                // 2. Main Card details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Request Title & Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Wild Bee Relocation $displayId',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Location
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppColors.hiveLow,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              location,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Submitted Date
                      Text(
                        'Submitted: $dateDisplay',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Status & Beekeeper badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 11, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Status: $status',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (beekeeper != null && beekeeper.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person_pin_rounded,
                                    size: 11,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Beekeeper: Assigned',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (status != 'Cancelled' && status != 'Completed')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgElevated,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Beekeeper: Searching nearby',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // 3. Action Buttons: Select Beekeeper + View Details
          Row(
            children: [
              if ((beekeeper == null || beekeeper.isEmpty) &&
                  status != 'Cancelled' &&
                  status != 'Completed')
                Expanded(
                  child: InkWell(
                    onTap: () => _openSelectBeekeeperSheet(report),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(15),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.hiveLow.withValues(alpha: 0.1),
                        border: const Border(
                          right: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.person_pin_circle_rounded,
                            size: 14,
                            color: AppColors.hiveLow,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Select Beekeeper',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.hiveLow,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: InkWell(
                  onTap: () => _openDetailsModal(report),
                  borderRadius: BorderRadius.only(
                    bottomRight: const Radius.circular(15),
                    bottomLeft: (beekeeper != null && beekeeper.isNotEmpty) ||
                            status == 'Cancelled' ||
                            status == 'Completed'
                        ? const Radius.circular(15)
                        : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View Details',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.hiveLow,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: AppColors.hiveLow,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hive Photo Thumbnail ────────────────────────────────────
  Widget _buildThumbnail(bool hasPhoto, String? photoUrl) {
    if (hasPhoto && photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('data:image')) {
        try {
          final base64Str = photoUrl.split(',').last;
          final bytes = base64Decode(base64Str);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          );
        } catch (_) {}
      } else if (photoUrl.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildFallbackThumbnail(),
            ),
          ),
        );
      }
    }
    return _buildFallbackThumbnail();
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.hiveLow.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.nature_people_rounded,
            color: AppColors.hiveLow,
            size: 24,
          ),
        ),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 44,
                color: AppColors.hiveLow,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Requests Found',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no $_selectedFilter relocation requests yet. Submit a wild bee report to save and track your request.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.hiveLow,
                foregroundColor: AppColors.bgSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_location_alt_rounded, size: 18),
              label: Text(
                'Report Wild Hive',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        const WildBeeHiveReportScreenIT23185302(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// VIEW DETAILS MODAL SHEET & TIMELINE WORKFLOW
// ════════════════════════════════════════════════════════════════

class _RequestDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> report;
  final VoidCallback onReportCancelled;
  final VoidCallback? onSelectBeekeeperTapped;

  const _RequestDetailsSheet({
    required this.report,
    required this.onReportCancelled,
    this.onSelectBeekeeperTapped,
  });

  @override
  State<_RequestDetailsSheet> createState() => _RequestDetailsSheetState();
}

class _RequestDetailsSheetState extends State<_RequestDetailsSheet> {
  bool _isCancelling = false;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.report['status']?.toString() ?? 'Submitted';
  }

  // Map status string to timeline step index (0 to 5)
  int _getCurrentTimelineStepIndex() {
    switch (_status) {
      case 'Submitted':
        return 0;
      case 'Under Review':
        return 1;
      case 'Waiting for Beekeeper':
        return 2;
      case 'Accepted':
        return 3;
      case 'Relocation Scheduled':
      case 'In Progress':
        return 4;
      case 'Completed':
        return 5;
      case 'Cancelled':
        return -1;
      default:
        return 0;
    }
  }

  Future<void> _handleCancelRequest() async {
    final reportId = widget.report['id']?.toString();
    if (reportId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Relocation Request?',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel this request? Once cancelled, nearby beekeepers will no longer be assigned.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep Request',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cancel Request',
              style: GoogleFonts.inter(
                color: AppColors.bgSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      await WildBeeService.instance.cancelReport(reportId);
      if (!mounted) return;
      setState(() {
        _isCancelling = false;
        _status = 'Cancelled';
      });
      widget.report['status'] = 'Cancelled';
      widget.onReportCancelled();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request $reportId has been cancelled.',
            style: GoogleFonts.inter(
              color: AppColors.bgSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.panelBlack,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showContactBeekeeperSheet(String name, String phone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.hiveLow.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.hiveLow,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
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
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Assigned Local Beekeeper',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_rounded,
                      color: AppColors.hiveLow, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    phone,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.bgSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.call_rounded, size: 19),
              label: Text(
                'Call Beekeeper',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Dialing $name ($phone)...',
                      style: GoogleFonts.inter(color: AppColors.bgSecondary),
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: Text(
                'Send SMS / Message',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Opening messaging with $name...',
                      style: GoogleFonts.inter(color: AppColors.bgSecondary),
                    ),
                    backgroundColor: AppColors.panelBlack,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAssessmentResultDialog() {
    final spot = widget.report['colony_location'] ?? 'Roof';
    final height = widget.report['height'] ?? '2–5 m';
    final inside = widget.report['inside_structure'] ?? 'Yes';
    final safe = widget.report['safe_access'] ?? 'Yes';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.hiveLow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: AppColors.hiveLow,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Assessment Result',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAssessmentRow('Target Species', 'Apis cerana indica (Asian Honeybee)'),
              _buildAssessmentRow('Feasibility Score', 'High (94% Safe Recovery)'),
              _buildAssessmentRow('Colony Location', '$spot (Height: $height)'),
              _buildAssessmentRow('Enclosed in Cavity', inside),
              _buildAssessmentRow('Direct Access Safe', safe),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended Equipment:',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Soft-vacuum swarm catcher\n• Herbal lemongrass lure & nuc transport box\n• Full protective veil & sting-proof gloves\n• Ladder extension (if above 2m)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.hiveLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Done',
              style: GoogleFonts.inter(
                color: AppColors.bgSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              val,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRelocationUpdatesSheet() {
    final updates = [
      {
        'time': 'Today, 09:30 AM',
        'title': 'Beekeeper Assigned',
        'desc': 'Local apiarist accepted the relocation assignment.',
        'icon': Icons.assignment_turned_in_rounded,
        'color': AppColors.success,
      },
      {
        'time': 'Yesterday, 04:15 PM',
        'title': 'Feasibility Assessment Passed',
        'desc': 'Species verified as non-aggressive native honeybee.',
        'icon': Icons.verified_outlined,
        'color': AppColors.info,
      },
      {
        'time': 'Yesterday, 02:00 PM',
        'title': 'Report Logged in System',
        'desc': 'Citizen report stored in Firestore and dispatched to nearby network.',
        'icon': Icons.cloud_done_rounded,
        'color': AppColors.hiveLow,
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Relocation Updates',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...updates.map((u) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (u['color'] as Color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        u['icon'] as IconData,
                        color: u['color'] as Color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                u['title'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                u['time'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            u['desc'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawId = widget.report['id']?.toString() ?? 'REL-2026';
    final displayId = widget.report['display_id']?.toString() ??
        (rawId.length >= 8 ? '#${rawId.substring(rawId.length - 4)}' : rawId);
    final address = widget.report['address']?.toString() ?? 'Sri Lanka';
    final gps = widget.report['gps_coordinates']?.toString() ?? '6.9271° N, 79.8612° E';
    final spot = widget.report['colony_location']?.toString() ?? 'Roof';
    final height = widget.report['height']?.toString() ?? '2–5 m';
    final beekeeperName = widget.report['assigned_beekeeper']?.toString();
    final beekeeperPhone = widget.report['assigned_phone']?.toString() ?? '+94 77 123 4567';

    final canCancel = _status == 'Submitted' ||
        _status == 'Under Review' ||
        _status == 'Waiting for Beekeeper' ||
        _status == 'Accepted';

    final isAccepted = _status == 'Accepted' ||
        _status == 'Relocation Scheduled' ||
        _status == 'In Progress' ||
        _status == 'Completed';

    final activeStep = _getCurrentTimelineStepIndex();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wild Bee Relocation $displayId',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Body Scroll
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── TIMELINE WORKFLOW ─────────────────────────────
                  Text(
                    'Relocation Workflow',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildTimelineStepper(activeStep),
                  const SizedBox(height: 24),

                  // ── ASSIGNED BEEKEEPER CARD (if accepted) ─────────
                  if (isAccepted && beekeeperName != null && beekeeperName.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.hiveLow
                                    .withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.hiveLow,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      beekeeperName,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Certified Apiarist • 4.9 ★ Rating',
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
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.hiveLow,
                                foregroundColor: AppColors.bgSecondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                              ),
                              icon: const Icon(Icons.call_rounded, size: 16),
                              label: Text(
                                'Contact Beekeeper',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () => _showContactBeekeeperSheet(
                                beekeeperName,
                                beekeeperPhone,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if ((beekeeperName == null || beekeeperName.isEmpty) &&
                      _status != 'Cancelled' &&
                      _status != 'Completed') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    AppColors.hiveLow.withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.person_pin_circle_rounded,
                                  color: AppColors.hiveLow,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No Beekeeper Assigned Yet',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Select a registered apiarist according to this hive\'s location.',
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
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.hiveLow,
                                foregroundColor: AppColors.bgSecondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                              ),
                              icon: const Icon(Icons.person_pin_circle_rounded,
                                  size: 16),
                              label: Text(
                                'Select Beekeeper by Location',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onSelectBeekeeperTapped?.call();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── QUICK ACTION BUTTONS ──────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.analytics_outlined,
                              size: 16, color: AppColors.hiveLow),
                          label: Text(
                            'View Assessment',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _showAssessmentResultDialog,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.feed_outlined,
                              size: 16, color: AppColors.hiveLow),
                          label: Text(
                            'Relocation Updates',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _showRelocationUpdatesSheet,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // ── HIVE DETAILS SPECIFICATIONS ───────────────────
                  Text(
                    'Hive Details',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildSpecRow('Colony Spot', spot),
                        const Divider(height: 16, color: AppColors.border),
                        _buildSpecRow('Estimated Height', height),
                        const Divider(height: 16, color: AppColors.border),
                        _buildSpecRow('GPS Coordinates', gps),
                        const Divider(height: 16, color: AppColors.border),
                        _buildSpecRow('Safe Accessibility', 'Yes, Ground Level'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── CANCEL REQUEST BUTTON ─────────────────────────
                  if (canCancel) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        icon: _isCancelling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.error,
                                  ),
                                ),
                              )
                            : const Icon(Icons.cancel_outlined, size: 17),
                        label: Text(
                          _isCancelling
                              ? 'Cancelling Request...'
                              : 'Cancel Request',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                        onPressed:
                            _isCancelling ? null : _handleCancelRequest,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Requests can only be cancelled before relocation begins',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            val,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // ── Vertical Timeline Stepper ───────────────────────────────
  Widget _buildTimelineStepper(int currentStep) {
    final steps = [
      {'title': 'Report Submitted', 'desc': 'Logged with GPS & photo details'},
      {'title': 'Assessment Completed', 'desc': 'Species verified as native honeybee'},
      {'title': 'Beekeeper Requested', 'desc': 'Dispatched to nearby certified apiarists'},
      {'title': 'Beekeeper Accepted', 'desc': 'Local rescuer claimed the hive task'},
      {'title': 'Relocation', 'desc': 'Safe removal & gentle transfer in progress'},
      {'title': 'Completed', 'desc': 'Colony ethically rehoused in sanctuary apiary'},
    ];

    if (currentStep == -1) {
      // Cancelled state
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: AppColors.error, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This request was cancelled before relocation began.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(steps.length, (idx) {
        final isCompleted = idx < currentStep;
        final isActive = idx == currentStep;
        final isLast = idx == steps.length - 1;

        Color dotColor;
        IconData dotIcon;

        if (isCompleted) {
          dotColor = AppColors.success;
          dotIcon = Icons.check_circle_rounded;
        } else if (isActive) {
          dotColor = AppColors.hiveLow;
          dotIcon = Icons.radio_button_checked_rounded;
        } else {
          dotColor = AppColors.border;
          dotIcon = Icons.radio_button_unchecked_rounded;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left icon and vertical connecting line
            Column(
              children: [
                Icon(dotIcon, size: 18, color: dotColor),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 34,
                    color: isCompleted
                        ? AppColors.success
                        : AppColors.border,
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Step title and description
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[idx]['title']!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isActive || isCompleted
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive
                            ? AppColors.hiveLow
                            : (isCompleted
                                ? AppColors.textPrimary
                                : AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      steps[idx]['desc']!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
