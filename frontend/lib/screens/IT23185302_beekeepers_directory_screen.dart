import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/wild_bee_service.dart';
import '../utils/theme.dart';
import 'normal_user_home_screen.dart';
import 'IT23185302_my_requests_screen.dart';
import 'IT23185302_wild_bee_hive_report_screen.dart';

/// Research Component IT23185302:
/// Beekeepers Directory Screen (Only queries real users registered as Bee Keepers in Firestore DB).
/// Features: Select Beekeeper according to location, location filters, and request assignment.
class BeekeepersDirectoryScreenIT23185302 extends StatefulWidget {
  final String? initialLocation;

  const BeekeepersDirectoryScreenIT23185302({
    super.key,
    this.initialLocation,
  });

  @override
  State<BeekeepersDirectoryScreenIT23185302> createState() =>
      _BeekeepersDirectoryScreenIT23185302State();
}

class _BeekeepersDirectoryScreenIT23185302State
    extends State<BeekeepersDirectoryScreenIT23185302> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _beekeepers = [];
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Location filter state
  String _selectedLocationFilter = 'All';
  String? _detectedCity;

  final List<String> _baseLocations = [
    'All',
    'Gampaha',
    'Colombo',
    'Kandy',
    'Kalutara',
    'Kurunegala',
    'Galle',
    'Matara',
    'Anuradhapura',
    'Ratnapura',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
      _selectedLocationFilter = widget.initialLocation!;
    }
    _loadBeekeepers();
    _detectLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    final loc = await WildBeeService.instance.detectCurrentLocation();
    if (loc != null && mounted) {
      setState(() {
        _detectedCity = loc['city'];
      });
    }
  }

  Future<void> _loadBeekeepers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final fetched = await AuthService.instance.fetchRegisteredBeekeepers();
      if (mounted) {
        setState(() {
          _beekeepers = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error loading registered beekeepers from DB: $e',
          name: 'BeekeepersDirectory');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not load beekeepers from database. Please ensure backend server is running.';
          _beekeepers = [];
          _isLoading = false;
        });
      }
    }
  }

  List<String> get _availableLocationFilters {
    final set = <String>{'All'};
    if (_detectedCity != null && _detectedCity!.isNotEmpty) {
      set.add(_detectedCity!);
    }
    for (final b in _beekeepers) {
      final addr = (b['area_address'] ?? '').toString();
      for (final loc in _baseLocations) {
        if (loc != 'All' && addr.toLowerCase().contains(loc.toLowerCase())) {
          set.add(loc);
        }
      }
    }
    for (final loc in _baseLocations) {
      set.add(loc);
    }
    return set.toList();
  }

  List<Map<String, dynamic>> get _filteredBeekeepers {
    var list = _beekeepers;

    // Filter by location if selected
    if (_selectedLocationFilter != 'All') {
      final loc = _selectedLocationFilter.toLowerCase();
      list = list.where((b) {
        final area = (b['area_address'] ?? '').toString().toLowerCase();
        final apiary = (b['apiary_name'] ?? '').toString().toLowerCase();
        final name = (b['name'] ?? '').toString().toLowerCase();
        return area.contains(loc) || apiary.contains(loc) || name.contains(loc);
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((b) {
        final name = (b['name'] ?? '').toString().toLowerCase();
        final apiary = (b['apiary_name'] ?? '').toString().toLowerCase();
        final area = (b['area_address'] ?? '').toString().toLowerCase();
        final phone = (b['phone'] ?? '').toString().toLowerCase();
        final email = (b['email'] ?? '').toString().toLowerCase();
        return name.contains(q) ||
            apiary.contains(q) ||
            area.contains(q) ||
            phone.contains(q) ||
            email.contains(q);
      }).toList();
    }

    return list;
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }

  void _onNavTapped(int index) {
    if (index == 3) return; // Already on Beekeepers

    if (index == 0) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const NormalUserHomeScreen()),
        );
      }
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

    if (index == 2) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MyRequestsScreenIT23185302(),
        ),
      );
      return;
    }
  }

  void _callBeekeeper(String name, String phone) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.call_rounded,
                color: AppColors.bgSecondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Calling $name at $phone...',
                style: GoogleFonts.inter(
                  color: AppColors.bgSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _messageBeekeeper(String name, String phone) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.chat_bubble_rounded,
                color: AppColors.bgSecondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Opening SMS messaging with $name ($phone)...',
                style: GoogleFonts.inter(
                  color: AppColors.bgSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.panelBlack,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Handles "Select Beekeeper" action
  void _handleSelectBeekeeper(Map<String, dynamic> beekeeper) {
    final name = (beekeeper['name'] ?? 'Beekeeper').toString();
    final phone = (beekeeper['phone'] ?? '').toString();
    final id = (beekeeper['id'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.hiveLow.withValues(alpha: 0.15),
                  child: const Icon(Icons.person_pin_rounded,
                      color: AppColors.hiveLow),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select $name',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        (beekeeper['area_address'] ?? 'Sri Lanka').toString(),
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
            Text(
              'How would you like to assign this beekeeper?',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Option 1: Start a new Wild Bee Hive Report
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const WildBeeHiveReportScreenIT23185302(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.hiveLow,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_location_alt_rounded,
                        color: AppColors.bgSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Relocation Report',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Submit colony details for ethical relocation by qualified beekeepers.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Assign to existing submitted report
            FutureBuilder<List<Map<String, dynamic>>>(
              future: WildBeeService.instance.fetchMyReports(),
              builder: (context, snapshot) {
                final reports = snapshot.data ?? [];
                final unassigned = reports
                    .where((r) =>
                        (r['assigned_beekeeper'] == null ||
                            r['assigned_beekeeper'].toString().isEmpty) &&
                        r['status'] != 'Cancelled' &&
                        r['status'] != 'Completed')
                    .toList();

                if (unassigned.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Or assign to an existing open report:',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...unassigned.map((r) {
                      final reportId = (r['id'] ?? '').toString();
                      final address = (r['address'] ?? 'Sri Lanka').toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await WildBeeService.instance.assignBeekeeper(
                                reportId: reportId,
                                beekeeperName: name,
                                beekeeperPhone: phone,
                                beekeeperId: id,
                              );
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Beekeeper $name successfully assigned to $reportId!',
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
                                    content: Text('Failed to assign beekeeper: $e'),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.assignment_turned_in_rounded,
                                    size: 18, color: AppColors.success),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '$reportId - $address',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.check_circle_outline_rounded,
                                    size: 16, color: AppColors.hiveLow),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableFilters = _availableLocationFilters;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'Select Beekeeper',
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
            onPressed: _loadBeekeepers,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search Box ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: TextFormField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name, apiary, location, or phone...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.bgSecondary,
                  isDense: true,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),
            ),

            // ── Location Filter Horizontal Chips ────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 2, bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 15,
                    color: AppColors.accent2,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filter by Location:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: availableFilters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final loc = availableFilters[i];
                  final isSelected = _selectedLocationFilter.toLowerCase() ==
                      loc.toLowerCase();

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedLocationFilter = loc;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.hiveLow
                            : AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.hiveLow
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (loc == 'All')
                            Icon(
                              Icons.public_rounded,
                              size: 13,
                              color: isSelected
                                  ? AppColors.bgSecondary
                                  : AppColors.textSecondary,
                            )
                          else
                            Icon(
                              Icons.location_city_rounded,
                              size: 13,
                              color: isSelected
                                  ? AppColors.bgSecondary
                                  : AppColors.accent2,
                            ),
                          const SizedBox(width: 5),
                          Text(
                            loc,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.bgSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // ── Live Status Banner ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.hiveLow.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.hiveLow.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 17,
                      color: AppColors.hiveLow,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isLoading
                            ? 'Connecting to database...'
                            : _selectedLocationFilter != 'All'
                                ? 'Showing beekeepers registered in or near $_selectedLocationFilter (${_filteredBeekeepers.length} found)'
                                : '${_filteredBeekeepers.length} registered beekeeper${_filteredBeekeepers.length == 1 ? '' : 's'} in database.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ── Body Content ────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.hiveLow,
                            ),
                          ),
                          SizedBox(height: 14),
                          Text('Loading registered beekeepers...'),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _filteredBeekeepers.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              color: AppColors.hiveLow,
                              onRefresh: _loadBeekeepers,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                itemCount: _filteredBeekeepers.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (context, i) {
                                  return _buildBeekeeperCard(
                                      _filteredBeekeepers[i]);
                                },
                              ),
                            ),
            ),
          ],
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
        currentIndex: 3, // Beekeepers tab
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

  Widget _buildEmptyState() {
    final isSearching =
        _searchQuery.trim().isNotEmpty || _selectedLocationFilter != 'All';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.bgElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching ? Icons.search_off_rounded : Icons.groups_outlined,
                size: 42,
                color: AppColors.hiveLow,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching
                  ? 'No Matches for "$_selectedLocationFilter"'
                  : 'No Registered Beekeepers in DB',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'No beekeeper found matching "$_selectedLocationFilter" or "$_searchQuery". Try selecting "All" or a nearby city.'
                  : 'There are currently no users registered as Bee Keepers in the database.\nWhen a beekeeper registers, they will appear here.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            if (isSearching)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: Text(
                  'Reset Filters',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedLocationFilter = 'All';
                  });
                },
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.panelBlack,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  'Refresh List',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                onPressed: _loadBeekeepers,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Unable to fetch registered beekeepers from database.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.hiveLow,
                foregroundColor: AppColors.bgSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'Try Again',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              onPressed: _loadBeekeepers,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeekeeperCard(Map<String, dynamic> b) {
    final name = (b['name'] ?? 'Beekeeper').toString().trim();
    final apiary = (b['apiary_name'] ?? 'Registered Apiary').toString().trim();
    final areaAddress = (b['area_address'] ?? 'Sri Lanka').toString().trim();
    final phone = (b['phone'] ?? '').toString().trim();
    final email = (b['email'] ?? '').toString().trim();
    final createdAt = b['created_at'];
    final formattedDate = _formatDate(createdAt);

    final isMatchingLocation = _selectedLocationFilter != 'All' &&
        areaAddress
            .toLowerCase()
            .contains(_selectedLocationFilter.toLowerCase());

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatchingLocation ? AppColors.hiveLow : AppColors.border,
          width: isMatchingLocation ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Avatar + Name/Apiary + Verified Badge
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.hiveLow.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'B',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              apiary,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.hiveLow.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.hiveLow.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_rounded,
                        size: 12,
                        color: AppColors.hiveLow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Bee Keeper',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.hiveLow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: AppColors.accent2,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    areaAddress,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isMatchingLocation
                          ? AppColors.hiveLow
                          : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMatchingLocation)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Matches Location',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Phone number
            Row(
              children: [
                Icon(
                  phone.isNotEmpty
                      ? Icons.phone_rounded
                      : Icons.phone_disabled_outlined,
                  size: 15,
                  color: phone.isNotEmpty
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  phone.isNotEmpty ? phone : 'No phone number provided',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: phone.isNotEmpty
                        ? FontWeight.w600
                        : FontWeight.w400,
                    fontStyle: phone.isNotEmpty
                        ? FontStyle.normal
                        : FontStyle.italic,
                    color: phone.isNotEmpty
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            // Email
            if (email.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.mail_outline_rounded,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Member since
            if (formattedDate.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Registered: $formattedDate',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // ── Primary Action: SELECT BEEKEEPER ────────────────────
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.hiveLow,
                  foregroundColor: AppColors.bgSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 17),
                label: Text(
                  'Select Beekeeper for Relocation',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => _handleSelectBeekeeper(b),
              ),
            ),
            const SizedBox(height: 8),

            // Secondary Actions: Call & Message
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: phone.isNotEmpty
                          ? AppColors.success
                          : AppColors.textSecondary,
                      side: BorderSide(
                        color: phone.isNotEmpty
                            ? AppColors.success
                            : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: Icon(
                      Icons.call_rounded,
                      size: 15,
                      color: phone.isNotEmpty
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                    label: Text(
                      'Call',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: phone.isNotEmpty
                        ? () => _callBeekeeper(name, phone)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: phone.isNotEmpty
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      side: BorderSide(
                        color: phone.isNotEmpty
                            ? AppColors.border
                            : AppColors.border.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: Icon(
                      Icons.chat_outlined,
                      size: 15,
                      color: phone.isNotEmpty
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    label: Text(
                      'Message',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: phone.isNotEmpty
                        ? () => _messageBeekeeper(name, phone)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
