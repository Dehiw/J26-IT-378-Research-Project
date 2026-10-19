import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/wild_bee_service.dart';
import '../utils/theme.dart';
import 'home_screen.dart';
import 'IT23183186_environment_dashboard_screen.dart';

/// Research Component IT23185302:
/// Beekeeper Wild Bee Relocation Requests Screen & Relocation Management Workflow.
class BeekeeperRequestsScreenIT23185302 extends StatefulWidget {
  final String initialFilter;
  const BeekeeperRequestsScreenIT23185302({
    super.key,
    this.initialFilter = 'All',
  });

  @override
  State<BeekeeperRequestsScreenIT23185302> createState() =>
      _BeekeeperRequestsScreenIT23185302State();
}

class _BeekeeperRequestsScreenIT23185302State
    extends State<BeekeeperRequestsScreenIT23185302> {
  final int _currentNavIndex = 2; // Relocate is index 2

  String _selectedFilter = 'All'; // 'All', 'Pending', 'Accepted', 'Completed'
  bool _isLoading = true;
  List<Map<String, dynamic>> _allRequests = [];

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final fetched = await WildBeeService.instance.fetchAllReports();
      developer.log('Loaded ${fetched.length} reports from Firestore',
          name: 'BeekeeperRequests');

      final currentBeekeeper = AuthService.instance.currentUser;

      // Filter: Only keep real reports where the user selected this beekeeper
      final filteredForBeekeeper = <Map<String, dynamic>>[];
      for (final r in fetched) {
        if (_isAssignedToCurrentBeekeeper(r, currentBeekeeper)) {
          filteredForBeekeeper.add(Map<String, dynamic>.from(r));
        }
      }

      if (mounted) {
        setState(() {
          _allRequests = filteredForBeekeeper;
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error loading requests: $e', name: 'BeekeeperRequests');
      if (mounted) {
        setState(() {
          _allRequests = [];
          _isLoading = false;
        });
      }
    }
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

  List<Map<String, dynamic>> get _filteredRequests {
    if (_selectedFilter == 'All') return _allRequests;
    return _allRequests.where((r) {
      final s = (r['status'] ?? '').toString().toLowerCase();
      if (_selectedFilter == 'Pending') {
        return s == 'pending' || s == 'submitted' || s == 'under review';
      }
      if (_selectedFilter == 'Accepted') {
        return s == 'accepted' || s == 'scheduled' || s == 'in progress';
      }
      if (_selectedFilter == 'Completed') {
        return s == 'completed' || s == 'done' || s == 'closed';
      }
      return true;
    }).toList();
  }

  int _countFor(String filter) {
    if (filter == 'All') return _allRequests.length;
    return _allRequests.where((r) {
      final s = (r['status'] ?? '').toString().toLowerCase();
      if (filter == 'Pending') {
        return s == 'pending' || s == 'submitted' || s == 'under review';
      }
      if (filter == 'Accepted') {
        return s == 'accepted' || s == 'scheduled' || s == 'in progress';
      }
      if (filter == 'Completed') {
        return s == 'completed' || s == 'done' || s == 'closed';
      }
      return true;
    }).length;
  }

  void _onNavTapped(int index) {
    if (index == _currentNavIndex) {
      Navigator.of(context).pop();
      return;
    }
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
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

  void _openDetails(Map<String, dynamic> request) async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => BeekeeperRequestDetailsScreenIT23185302(request: request),
      ),
    );

    if (updated != null) {
      // Update local state and reload list from Firestore
      setState(() {
        final idx = _allRequests.indexWhere((r) => r['id'] == updated['id']);
        if (idx != -1) {
          _allRequests[idx] = updated;
        }
      });
      _loadRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRequests;

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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Wild Bee Requests | IT23185302',
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
            onPressed: _loadRequests,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            // ── FILTER TABS: All | Pending | Accepted | Completed ─────
            _buildFilterTabs(),

            const SizedBox(height: 12),

            // ── LIST OF REQUEST CARDS ─────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.hiveLow),
                      ),
                    )
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: AppColors.hiveLow,
                          onRefresh: _loadRequests,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 6),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) {
                              final item = filtered[i];
                              return _WildBeeRequestCard(
                                request: item,
                                onTap: () => _openDetails(item),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Filter Tabs ───────────────────────────────────────────────────

  Widget _buildFilterTabs() {
    final tabs = ['All', 'Pending', 'Accepted', 'Completed'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: tabs.map((t) {
          final isSelected = _selectedFilter == t;
          final count = _countFor(t);

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.panelBlack : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      t,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? AppColors.bgSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.hiveLow
                            : AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.textPrimary
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 28,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No $_selectedFilter Requests',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Relocation requests submitted by users will automatically show up here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
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

// ═══════════════════════════════════════════════════════════════════════════
// Request Card Widget (Matching Prompt Layout Exactly)
// ═══════════════════════════════════════════════════════════════════════════

class _WildBeeRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onTap;

  const _WildBeeRequestCard({
    required this.request,
    required this.onTap,
  });

  String _formatDisplayId(String? id, String? displayId) {
    if (displayId != null && displayId.isNotEmpty) return displayId;
    if (id == null || id.isEmpty) return '#REQ';
    final parts = id.split('-');
    if (parts.isNotEmpty) {
      final last = parts.last;
      return '#${last.length > 5 ? last.substring(0, 4) : last}';
    }
    return '#REQ';
  }

  String _formatDate(String? raw, String? fallback) {
    if (fallback != null && fallback.isNotEmpty) return fallback;
    if (raw == null || raw.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(raw);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      if (raw.length >= 10) return raw.substring(0, 10);
      return raw;
    }
  }

  String _getAssessmentLevel(Map<String, dynamic> r) {
    if (r['assessment_level'] != null) {
      return r['assessment_level'].toString();
    }
    final loc = (r['colony_location'] ?? '').toString().toLowerCase();
    final height = (r['height'] ?? '').toString().toLowerCase();
    final inside = (r['inside_structure'] ?? '').toString().toLowerCase();

    if (loc.contains('roof') || height.contains('above 5') || inside == 'yes') {
      return 'Expert Assistance Required';
    }
    if (loc.contains('tree') && height.contains('below 2')) {
      return 'Low Risk Relocation';
    }
    return 'Routine Professional Relocation';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return AppColors.success;
      case 'accepted':
      case 'scheduled':
      case 'in progress':
        return AppColors.hiveLow;
      case 'declined':
      case 'cancelled':
        return AppColors.error;
      case 'pending':
      case 'submitted':
      case 'under review':
      default:
        return AppColors.accent2;
    }
  }

  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return AppColors.badgeLeafBg;
      case 'accepted':
      case 'scheduled':
      case 'in progress':
        return AppColors.badgeBeeBg;
      case 'declined':
      case 'cancelled':
        return AppColors.badgeTempBg;
      case 'pending':
      case 'submitted':
      case 'under review':
      default:
        return AppColors.badgeTempBg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (request['status'] ?? 'Pending').toString();
    final displayId =
        _formatDisplayId(request['id']?.toString(), request['display_id']?.toString());
    final address = request['address']?.toString() ?? 'Sri Lanka';
    final dateStr =
        _formatDate(request['created_at']?.toString(), request['date_display']?.toString());
    final colonyLocation = request['colony_location']?.toString() ?? 'Colony';
    final assessment = _getAssessmentLevel(request);

    final statusColor = _statusColor(status);
    final statusBg = _statusBg(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: Title + Status Badge ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Wild Bee Relocation $displayId',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Location & Date Row ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 15,
                  color: AppColors.accent2,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // ── Colony Location & Assessment ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column 1: Colony Location
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Colony Location',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            colonyLocation.toLowerCase().contains('roof')
                                ? Icons.roofing_rounded
                                : colonyLocation.toLowerCase().contains('wall')
                                    ? Icons.fence_rounded
                                    : Icons.park_rounded,
                            size: 15,
                            color: AppColors.hiveLow,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              colonyLocation,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Column 2: Assessment
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assessment',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        assessment,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: assessment.contains('Expert')
                              ? AppColors.accent2
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── View Request Details Button ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              height: 42,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgElevated,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View Request Details',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.hiveLow,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Detailed Request View & Management Screen
// ═══════════════════════════════════════════════════════════════════════════

class BeekeeperRequestDetailsScreenIT23185302 extends StatefulWidget {
  final Map<String, dynamic> request;

  const BeekeeperRequestDetailsScreenIT23185302({
    super.key,
    required this.request,
  });

  @override
  State<BeekeeperRequestDetailsScreenIT23185302> createState() =>
      _BeekeeperRequestDetailsScreenIT23185302State();
}

class _BeekeeperRequestDetailsScreenIT23185302State
    extends State<BeekeeperRequestDetailsScreenIT23185302> {
  late Map<String, dynamic> _data;
  bool _isSaving = false;
  final _notesController = TextEditingController();
  final List<File> _completionPhotos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.request);
    _notesController.text =
        _data['relocation_notes']?.toString() ?? _data['notes']?.toString() ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String get _currentStatus => (_data['status'] ?? 'Pending').toString();

  bool get _isAccepted =>
      ['accepted', 'scheduled', 'in progress', 'completed']
          .contains(_currentStatus.toLowerCase());

  bool get _isCompleted =>
      ['completed', 'done', 'closed'].contains(_currentStatus.toLowerCase());

  String _getDisplayId() {
    final id = _data['id']?.toString() ?? _data['display_id']?.toString() ?? '';
    if (id.isEmpty) return '#REQ';
    final parts = id.split('-');
    if (parts.isNotEmpty) {
      final last = parts.last;
      return '#${last.length > 5 ? last.substring(0, 4) : last}';
    }
    return '#REQ';
  }

  // ── Firestore Sync Handler ────────────────────────────────────────

  Future<void> _updateBackend(Map<String, dynamic> updates) async {
    setState(() => _isSaving = true);
    final reportId = _data['id']?.toString() ?? '';

    try {
      if (reportId.isNotEmpty) {
        await WildBeeService.instance.manageReport(
          reportId: reportId,
          updates: updates,
        );
      }
      setState(() {
        _data.addAll(updates);
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text(
              'Relocation request updated in Firestore.',
              style: GoogleFonts.inter(
                color: AppColors.bgSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      developer.log('Error syncing to Firestore: $e',
          name: 'BeekeeperRequestDetails');
      // Still update local data gracefully
      setState(() {
        _data.addAll(updates);
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.panelBlack,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text(
              'Status updated locally ($e)',
              style: GoogleFonts.inter(color: AppColors.bgSecondary),
            ),
          ),
        );
      }
    }
  }

  // ── Action: Accept Request ────────────────────────────────────────

  void _acceptRequest() {
    final beekeeper = AuthService.instance.currentUser;
    _updateBackend({
      'status': 'Accepted',
      'assigned_beekeeper': beekeeper?.name ?? 'Assigned Beekeeper',
      'assigned_phone': '+94 77 412 8990',
    });
  }

  // ── Action: Decline Request ────────────────────────────────────────

  void _declineRequest() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Decline Request?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to decline this wild bee relocation request? The homeowner will be notified to reach another apiary expert.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateBackend({
                'status': 'Declined',
                'declined_reason': 'Beekeeper unavailable in current area.',
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.bgSecondary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Decline',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action: Schedule Relocation ───────────────────────────────────

  Future<void> _scheduleRelocation() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.hiveLow,
              onPrimary: AppColors.bgSecondary,
              surface: AppColors.bgSecondary,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.hiveLow,
              onPrimary: AppColors.bgSecondary,
              surface: AppColors.bgSecondary,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    final dateStr =
        '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';

    _updateBackend({
      'status': 'Scheduled',
      'scheduled_date': dateStr,
      'scheduled_time': timeStr,
    });
  }

  // ── Action: Mark Completed ────────────────────────────────────────

  void _markCompleted() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 24),
            const SizedBox(width: 8),
            Text(
              'Mark Completed',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Confirm that the wild colony has been safely rescued and relocated to your apiary?',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateBackend({
                'status': 'Completed',
                'relocation_notes': _notesController.text.trim(),
                'completion_notes':
                    'Colony successfully boxed and transferred.',
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.bgSecondary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Confirm Completed',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action: Add Photo ─────────────────────────────────────────────

  Future<void> _addPhoto(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (xFile != null) {
        if (!mounted) return;
        setState(() {
          _completionPhotos.add(File(xFile.path));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              'Photo added to relocation report.',
              style: GoogleFonts.inter(color: AppColors.bgSecondary),
            ),
          ),
        );
      }
    } catch (e) {
      developer.log('Photo pick error: $e', name: 'BeekeeperRequestDetails');
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayId = _getDisplayId();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary, size: 24),
            onPressed: () => Navigator.of(context).pop(_data),
          ),
          title: Text(
            'IT23185302 | Relocation $displayId',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(right: 16),
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
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Status Banner ───────────────────────────────────
                _buildStatusBanner(),
                const SizedBox(height: 20),

                // ── 1. Colony Information ───────────────────────────
                _buildSectionTitle(
                  title: '1. Colony Information',
                  subtitle: 'Reported nesting spot, structure, and height',
                  icon: Icons.bug_report_outlined,
                ),
                const SizedBox(height: 10),
                _buildColonyInformationCard(),
                const SizedBox(height: 22),

                // ── 2. AI Assessment Result ─────────────────────────
                _buildSectionTitle(
                  title: '2. AI Assessment Result',
                  subtitle: 'Automated triage and hazard evaluation',
                  icon: Icons.psychology_rounded,
                ),
                const SizedBox(height: 10),
                _buildAiAssessmentCard(),
                const SizedBox(height: 22),

                // ── 3. Location & GPS Map ───────────────────────────
                _buildSectionTitle(
                  title: '3. Location & Reported GPS',
                  subtitle: 'Reported coordinate pin and neighborhood',
                  icon: Icons.map_outlined,
                ),
                const SizedBox(height: 10),
                _buildLocationCard(),
                const SizedBox(height: 22),

                // ── 4. Homeowner Details ────────────────────────────
                _buildSectionTitle(
                  title: '4. Homeowner Details',
                  subtitle: 'Contact info provided for this relocation',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 10),
                _buildHomeownerCard(),
                const SizedBox(height: 22),

                // ── 5. Request Actions & Lifecycle Management ───────
                _buildSectionTitle(
                  title: '5. Request Actions',
                  subtitle: _isAccepted
                      ? 'Manage relocation schedule, notes, and completion'
                      : 'Accept or decline this relocation request',
                  icon: Icons.handyman_outlined,
                ),
                const SizedBox(height: 10),
                _buildRequestActionsCard(),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section Title Helper ──────────────────────────────────────────

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.hiveLow),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Status Banner ─────────────────────────────────────────────────

  Widget _buildStatusBanner() {
    final status = _currentStatus;
    Color color;
    Color bg;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'completed':
        color = AppColors.success;
        bg = AppColors.badgeLeafBg;
        icon = Icons.check_circle_rounded;
        break;
      case 'accepted':
      case 'scheduled':
      case 'in progress':
        color = AppColors.hiveLow;
        bg = AppColors.badgeBeeBg;
        icon = Icons.timelapse_rounded;
        break;
      case 'declined':
      case 'cancelled':
        color = AppColors.error;
        bg = AppColors.badgeTempBg;
        icon = Icons.cancel_rounded;
        break;
      default:
        color = AppColors.accent2;
        bg = AppColors.badgeTempBg;
        icon = Icons.pending_actions_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $status',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  _isAccepted
                      ? (_data['scheduled_date'] != null
                          ? 'Scheduled for ${_data['scheduled_date']} (${_data['scheduled_time'] ?? '09:00 AM'})'
                          : 'Accepted — Please contact homeowner to schedule visit.')
                      : 'Pending review by certified beekeeper.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
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

  // ── Section 1: Colony Information Card ────────────────────────────

  Widget _buildColonyInformationCard() {
    final colonyLocation = _data['colony_location']?.toString() ?? 'Roof';
    final height = _data['height']?.toString() ?? '2–5 m';
    final inside = _data['inside_structure']?.toString() ?? 'Yes';
    final safeAccess = _data['safe_access']?.toString() ?? 'Yes';
    final notes = _data['notes']?.toString();
    final photoUrl = _data['photo_url']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo preview
          if (photoUrl != null && photoUrl.startsWith('data:image'))
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(photoUrl.split(',').last),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 28,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Colony Nesting Area Photo',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Captured by homeowner at time of report',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Detail Grid
          _buildInfoRow('Colony Spot', colonyLocation, Icons.location_pin),
          _buildInfoRow('Approx. Height', height, Icons.height_rounded),
          _buildInfoRow('Inside Structure', inside, Icons.home_rounded),
          _buildInfoRow('Safe Ground Access', safeAccess, Icons.check_circle_outline),

          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Text(
              'Homeowner Description:',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              notes,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.hiveLow),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 2: AI Assessment Result Card ──────────────────────────

  Widget _buildAiAssessmentCard() {
    final level = _data['assessment_level']?.toString() ??
        'Expert Assistance Required';
    final confidence = _data['confidence']?.toString() ?? '94%';
    final concerns = _data['main_concerns'] as List<dynamic>? ?? [
      'Elevated roof cavity (>3m)',
      'Potential enclosed rafter nesting',
      'Risk of stinging nearby occupants',
    ];
    final action = _data['recommended_action']?.toString() ??
        'Specialized bee-vacuum extraction with safety ladder and thermal comb imaging. Isolate attic entrance before opening soffit.';

    final isExpert = level.contains('Expert');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpert
              ? AppColors.accent2.withValues(alpha: 0.35)
              : AppColors.success.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level + Confidence Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Predicted Intervention Level',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isExpert ? AppColors.accent2 : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.panelBlack,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      confidence,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.hiveTop,
                      ),
                    ),
                    Text(
                      'AI Confidence',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Main concerns list
          Text(
            'Main Concerns Identified:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ...concerns.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: AppColors.accent2,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        c.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Recommended Next Action
          Text(
            'Recommended Next Action:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              action,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 3: Location Card & Canvas Map ─────────────────────────

  Widget _buildLocationCard() {
    final address = _data['address']?.toString() ?? 'Nittambuwa, Sri Lanka';
    final gps =
        _data['gps_coordinates']?.toString() ?? '7.1444° N, 80.0983° E';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stylized Interactive Map Canvas
          Container(
            height: 130,
            decoration: const BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapCanvasPainter(),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent2,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent2.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.bgSecondary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.panelBlack.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          gps,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.bgSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Reported Coordinates: $gps',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening GPS route for: $address'),
                        backgroundColor: AppColors.panelBlack,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.directions_rounded, size: 15),
                  label: const Text('Directions'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.hiveLow,
                    side: const BorderSide(color: AppColors.hiveLow),
                    textStyle: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 4: Homeowner Details Card ─────────────────────────────

  Widget _buildHomeownerCard() {
    final name = _data['homeowner_name']?.toString() ??
        _data['user_name']?.toString() ??
        'Sunil Jayawardena';
    final phone = _data['homeowner_phone']?.toString() ??
        _data['user_phone']?.toString() ??
        '+94 77 123 4567';
    final email = _data['homeowner_email']?.toString() ??
        _data['user_email']?.toString() ??
        'sunil.j@gmail.com';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: GoogleFonts.inter(
                      fontSize: 18,
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
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      phone,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Calling homeowner: $phone'),
                        backgroundColor: AppColors.panelBlack,
                      ),
                    );
                  },
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.bgSecondary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening messaging for: $phone'),
                        backgroundColor: AppColors.panelBlack,
                      ),
                    );
                  },
                  icon: const Icon(Icons.message_rounded, size: 16),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  // ── Section 5: Request Actions & Management ───────────────────────

  Widget _buildRequestActionsCard() {
    if (!_isAccepted) {
      // Pending request: show Accept or Decline
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Accept or Decline Wild Bee Request',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'By accepting, you agree to inspect the colony site and coordinate relocation with the homeowner.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _acceptRequest,
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 18),
                    label: const Text('Accept Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.hiveLow,
                      foregroundColor: AppColors.bgSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: _declineRequest,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Accepted request: Full Lifecycle Management
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step progress indicator: Accepted → Scheduled → In Progress → Completed
          _buildLifecycleStepper(),
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          // Schedule Relocation Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Relocation Schedule',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _data['scheduled_date'] != null
                        ? '${_data['scheduled_date']} at ${_data['scheduled_time'] ?? '09:00 AM'}'
                        : 'Not yet scheduled with homeowner',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _isCompleted ? null : _scheduleRelocation,
                icon: const Icon(Icons.event_available_rounded, size: 16),
                label: Text(_data['scheduled_date'] != null
                    ? 'Reschedule'
                    : 'Schedule'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.hiveLow,
                  side: const BorderSide(color: AppColors.hiveLow),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // Relocation Notes
          Text(
            'Relocation Notes:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            enabled: !_isCompleted,
            maxLines: 3,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText:
                  'Add field observations, hive box ID, queen status, or special extraction notes...',
              hintStyle: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.bgElevated,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!_isCompleted)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  _updateBackend({
                    'relocation_notes': _notesController.text.trim(),
                  });
                },
                icon: const Icon(Icons.save_rounded, size: 14),
                label: const Text('Save Notes'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.hiveLow,
                  textStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // Completion Photos
          Text(
            'Completion Photos:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._completionPhotos.map((f) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      f,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  )),
              if (!_isCompleted)
                GestureDetector(
                  onTap: () => _addPhoto(ImageSource.gallery),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      size: 20,
                      color: AppColors.hiveLow,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Mark Relocation Completed Button
          if (!_isCompleted)
            ElevatedButton.icon(
              onPressed: _markCompleted,
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Mark Relocation Completed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.bgSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.badgeLeafBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_rounded,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Relocation Successfully Completed',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Lifecycle Stepper Helper ──────────────────────────────────────

  Widget _buildLifecycleStepper() {
    final steps = ['Accepted', 'Scheduled', 'In Progress', 'Completed'];
    final currentIdx = steps.indexWhere(
      (s) => s.toLowerCase() == _currentStatus.toLowerCase(),
    );
    final activeIdx = currentIdx == -1 ? 0 : currentIdx;

    return Row(
      children: List.generate(steps.length, (i) {
        final isDone = i <= activeIdx;
        final isCurrent = i == activeIdx;

        return Expanded(
          child: GestureDetector(
            onTap: _isCompleted
                ? null
                : () {
                    _updateBackend({'status': steps[i]});
                  },
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= activeIdx
                                ? AppColors.hiveLow
                                : AppColors.border),
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isDone ? AppColors.hiveLow : AppColors.bgElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.hiveTop
                              : (isDone
                                  ? AppColors.hiveLow
                                  : AppColors.border),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check,
                                size: 12, color: AppColors.bgSecondary)
                            : Text(
                                '${i + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == steps.length - 1
                            ? Colors.transparent
                            : (i < activeIdx
                                ? AppColors.hiveLow
                                : AppColors.border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  steps[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                    color: isDone
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── CUSTOM CANVAS PAINTER FOR MAP PREVIEW ─────────────────────────

class _MapCanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final roadPaintSecondary = Paint()
      ..color = AppColors.border.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw stylized road grid
    final path1 = Path()
      ..moveTo(0, size.height * 0.3)
      ..lineTo(size.width, size.height * 0.7);

    final path2 = Path()
      ..moveTo(size.width * 0.2, 0)
      ..lineTo(size.width * 0.8, size.height);

    final path3 = Path()
      ..moveTo(0, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.2, size.width,
          size.height * 0.45);

    canvas.drawPath(path1, roadPaint);
    canvas.drawPath(path2, roadPaintSecondary);
    canvas.drawPath(path3, roadPaintSecondary);

    final ringPaint = Paint()
      ..color = AppColors.hiveLow.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 24, ringPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 44, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
