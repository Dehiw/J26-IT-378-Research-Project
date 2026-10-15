import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/apiary_model.dart';
import '../services/apiary_service.dart';
import '../utils/theme.dart';
import 'add_hive_screen.dart';

/// Hive Box list screen — matches the style of first_time_setup_screen.dart.
class HiveListScreen extends StatefulWidget {
  final ApiaryModel apiary;
  const HiveListScreen({super.key, required this.apiary});

  @override
  State<HiveListScreen> createState() => _HiveListScreenState();
}

class _HiveListScreenState extends State<HiveListScreen> {
  static const Color _darkGreen = Color(0xFF2C5E43);
  static const Color _lightGreenCard = Color(0xFFEAF2EC);

  List<HiveModel> _hives = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHives();
  }

  Future<void> _loadHives() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ApiaryService.instance.fetchHives(widget.apiary.id);
      if (mounted) setState(() { _hives = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openAddHive() async {
    final result = await Navigator.of(context).push<HiveModel>(
      MaterialPageRoute(builder: (_) => AddHiveScreen(apiary: widget.apiary)),
    );
    if (result != null) {
      setState(() {
        if (!_hives.any((h) => h.id == result.id)) {
          _hives.add(result);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _darkGreen,
            behavior: SnackBarBehavior.floating,
            content: Text('${result.name} created with ${result.numFrames} frames!',
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.apiary.locationName, style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text('Hive Boxes', style: GoogleFonts.inter(
            fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _darkGreen))
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    color: _darkGreen,
                    onRefresh: _loadHives,
                    child: CustomScrollView(slivers: [
                      SliverToBoxAdapter(child: _buildApiarySummary()),
                      if (_hives.isEmpty)
                        SliverFillRemaining(child: _buildEmpty())
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _HiveCard(
                                  hive: _hives[i],
                                  darkGreen: _darkGreen,
                                  lightGreenCard: _lightGreenCard),
                              childCount: _hives.length,
                            ),
                          ),
                        ),
                    ]),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddHive,
        backgroundColor: _darkGreen,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Hive Box', style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  Widget _buildApiarySummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2EC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const Icon(Icons.location_on_rounded, color: _darkGreen, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.apiary.locationName, style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text(widget.apiary.areaAddress, style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.textSecondary)),
          ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_hives.length}', style: GoogleFonts.inter(
            fontSize: 26, fontWeight: FontWeight.w800, color: _darkGreen)),
          Text('Hive Boxes', style: GoogleFonts.inter(
            fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 48),
        const SizedBox(height: 12),
        Text('Failed to load hives', style: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text(_error!, style: GoogleFonts.inter(
          fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loadHives,
          style: ElevatedButton.styleFrom(backgroundColor: _darkGreen,
            foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text('Retry', style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72,
          decoration: BoxDecoration(
            color: _lightGreenCard, borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.hive_outlined, color: _darkGreen, size: 36)),
        const SizedBox(height: 16),
        Text('No Hive Boxes Yet', style: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Tap "+ Add Hive Box" to register your first beehive here.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── Hive Card ──────────────────────────────────────────────────────

class _HiveCard extends StatelessWidget {
  final HiveModel hive;
  final Color darkGreen;
  final Color lightGreenCard;
  const _HiveCard({required this.hive, required this.darkGreen, required this.lightGreenCard});

  @override
  Widget build(BuildContext context) {
    final isHealthy = hive.status.toLowerCase() == 'healthy';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: lightGreenCard, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(
            '#${hive.boxNumber.toString().padLeft(2, '0')}',
            style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w800, color: darkGreen))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hive.name, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.grid_view_rounded, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${hive.numFrames} Frames', style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              if (hive.installationDate != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 13,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(hive.installationDate!, style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
            ],
          ),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isHealthy ? lightGreenCard : AppColors.badgeTempBg,
            borderRadius: BorderRadius.circular(8)),
          child: Text(hive.status, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: isHealthy ? darkGreen : AppColors.error)),
        ),
      ]),
    );
  }
}
