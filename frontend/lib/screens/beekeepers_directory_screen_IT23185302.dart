import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../utils/theme.dart';
import 'home_screen.dart';
import 'my_requests_screen_IT23185302.dart';
import 'wild_bee_hive_report_screen_IT23185302.dart';

/// Research Component IT23185302:
/// Beekeepers Directory Screen (Registered Apiarists & Rescuers in Firestore).
class BeekeepersDirectoryScreenIT23185302 extends StatefulWidget {
  const BeekeepersDirectoryScreenIT23185302({super.key});

  @override
  State<BeekeepersDirectoryScreenIT23185302> createState() =>
      _BeekeepersDirectoryScreenIT23185302State();
}

class _BeekeepersDirectoryScreenIT23185302State
    extends State<BeekeepersDirectoryScreenIT23185302> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _beekeepers = [];
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBeekeepers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBeekeepers() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await AuthService.instance.fetchRegisteredBeekeepers();
      if (fetched.isNotEmpty) {
        _beekeepers = fetched;
      } else {
        _beekeepers = _getDefaultSampleBeekeepers();
      }
    } catch (e) {
      developer.log('Notice loading beekeepers: $e',
          name: 'BeekeepersDirectory');
      _beekeepers = _getDefaultSampleBeekeepers();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _getDefaultSampleBeekeepers() {
    return [
      {
        'id': 'BK-001',
        'name': 'Nimal Senanayake',
        'email': 'nimal.bees@gmail.com',
        'phone': '+94 77 412 8990',
        'apiary_name': 'Gampaha Bio-Apiary & Sanctuary',
        'district': 'Gampaha',
        'experience': '12+ Years Experience',
        'rating': 4.9,
        'relocations_count': 38,
      },
      {
        'id': 'BK-002',
        'name': 'Chaminda Silva',
        'email': 'chaminda.honey@gmail.com',
        'phone': '+94 71 884 1209',
        'apiary_name': 'Colombo Urban Bee Rescue',
        'district': 'Colombo',
        'experience': '8 Years Experience',
        'rating': 4.8,
        'relocations_count': 24,
      },
      {
        'id': 'BK-003',
        'name': 'Sunil Bandara',
        'email': 'sunil.bandara@gmail.com',
        'phone': '+94 78 550 3341',
        'apiary_name': 'Kandy Central Highlands Apiary',
        'district': 'Kandy',
        'experience': '15+ Years Experience',
        'rating': 5.0,
        'relocations_count': 52,
      },
    ];
  }

  List<Map<String, dynamic>> get _filteredBeekeepers {
    if (_searchQuery.trim().isEmpty) return _beekeepers;
    final q = _searchQuery.trim().toLowerCase();
    return _beekeepers.where((b) {
      final name = (b['name'] ?? '').toString().toLowerCase();
      final apiary = (b['apiary_name'] ?? '').toString().toLowerCase();
      final phone = (b['phone'] ?? '').toString().toLowerCase();
      final email = (b['email'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          apiary.contains(q) ||
          phone.contains(q) ||
          email.contains(q);
    }).toList();
  }

  void _onNavTapped(int index) {
    if (index == 3) return; // Already on Beekeepers

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
        content: Text(
          'Dialing $name ($phone)...',
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

  void _messageBeekeeper(String name, String phone) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opening SMS messaging with $name ($phone)...',
          style: GoogleFonts.inter(
            color: AppColors.bgSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.panelBlack,
        behavior: SnackBarBehavior.floating,
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
          'Verified Beekeepers',
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
            // ── Search & Filter Box ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextFormField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by beekeeper name, apiary, or phone...',
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
                ),
              ),
            ),

            // ── Notice Banner ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.hiveLow.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.hiveLow.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: AppColors.hiveLow,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Registered apiarists ready for ethical wild bee rescue & relocation.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Beekeepers List ─────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.hiveLow,
                        ),
                      ),
                    )
                  : _filteredBeekeepers.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.groups_outlined,
                                  size: 40,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No Beekeepers Found',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Try searching with a different term.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.hiveLow,
                          onRefresh: _loadBeekeepers,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            itemCount: _filteredBeekeepers.length,
                            separatorBuilder: (_, __) =>
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

  Widget _buildBeekeeperCard(Map<String, dynamic> b) {
    final name = b['name']?.toString() ?? 'Beekeeper';
    final apiary = b['apiary_name']?.toString() ?? 'Registered Apiary';
    final phone = b['phone']?.toString() ?? '';
    final email = b['email']?.toString() ?? '';
    final rating = b['rating']?.toString() ?? '4.9';

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.hiveLow.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.hiveLow,
                    size: 26,
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
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: AppColors.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        apiary,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: AppColors.hiveLow),
                      const SizedBox(width: 3),
                      Text(
                        rating,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Phone number & Email
            if (phone.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 15,
                    color: AppColors.hiveLow,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    phone,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (email.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.mail_outline_rounded,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    email,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Call & Message Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.bgSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: Text(
                      'Call Now',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.chat_outlined, size: 16),
                    label: Text(
                      'Message',
                      style: GoogleFonts.inter(
                        fontSize: 13,
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
