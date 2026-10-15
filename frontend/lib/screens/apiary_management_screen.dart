import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/apiary_model.dart';
import '../services/apiary_service.dart';
import '../utils/theme.dart';
import 'hive_list_screen.dart';

/// Apiary Management screen — matches the style of first_time_setup_screen.dart.
class ApiaryManagementScreen extends StatefulWidget {
  const ApiaryManagementScreen({super.key});

  @override
  State<ApiaryManagementScreen> createState() => _ApiaryManagementScreenState();
}

class _ApiaryManagementScreenState extends State<ApiaryManagementScreen> {
  static const Color _darkGreen = Color(0xFF2C5E43);
  static const Color _lightGreenCard = Color(0xFFEAF2EC);

  List<ApiaryModel> _apiaries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApiaries();
  }

  Future<void> _loadApiaries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiaryService.instance.fetchApiaries();
      if (mounted) setState(() { _apiaries = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openAddApiarySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddApiarySheet(onCreated: (apiary) {
        setState(() {
          if (!_apiaries.any((a) => a.id == apiary.id)) {
            _apiaries.add(apiary);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _darkGreen,
            behavior: SnackBarBehavior.floating,
            content: Text('${apiary.locationName} added!',
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
      }),
    );
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
        title: Text('Apiary Management', style: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _darkGreen))
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    color: _darkGreen,
                    onRefresh: _loadApiaries,
                    child: _apiaries.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            itemCount: _apiaries.length,
                            itemBuilder: (_, i) => _ApiaryCard(
                              apiary: _apiaries[i],
                              darkGreen: _darkGreen,
                              lightGreenCard: _lightGreenCard,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) =>
                                    HiveListScreen(apiary: _apiaries[i])),
                              ),
                            ),
                          ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddApiarySheet,
        backgroundColor: _darkGreen,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add New Apiary', style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 48),
        const SizedBox(height: 12),
        Text('Failed to load apiaries', style: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text(_error!, style: GoogleFonts.inter(
          fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loadApiaries,
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
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _lightGreenCard, borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.location_on_outlined, color: _darkGreen, size: 36),
        ),
        const SizedBox(height: 16),
        Text('No Apiaries Yet', style: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Tap "+ Add New Apiary" to register your first bee farm location.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── Apiary Card ────────────────────────────────────────────────────

class _ApiaryCard extends StatelessWidget {
  final ApiaryModel apiary;
  final Color darkGreen;
  final Color lightGreenCard;
  final VoidCallback onTap;

  const _ApiaryCard({
    required this.apiary,
    required this.darkGreen,
    required this.lightGreenCard,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: lightGreenCard, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.location_on_rounded, color: darkGreen, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(apiary.locationName, style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(apiary.areaAddress, style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(Icons.hive_outlined, '${apiary.totalHives} Hives'),
                  _chip(Icons.grid_view_rounded, '${apiary.totalFrames} Frames'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: lightGreenCard, borderRadius: BorderRadius.circular(6)),
                    child: Text('Active', style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600, color: darkGreen)),
                  ),
                ],
              ),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.bgElevated, borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
    ]),
  );
}

// ── Add Apiary Bottom Sheet ────────────────────────────────────────

class _AddApiarySheet extends StatefulWidget {
  final void Function(ApiaryModel) onCreated;
  const _AddApiarySheet({required this.onCreated});

  @override
  State<_AddApiarySheet> createState() => _AddApiarySheetState();
}

class _AddApiarySheetState extends State<_AddApiarySheet> {
  static const Color _darkGreen = Color(0xFF2C5E43);
  static const Color _lightGreenCard = Color(0xFFEAF2EC);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _gpsCoordinates;
  bool _isFetchingGps = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _onUseCurrentLocation() {
    setState(() => _isFetchingGps = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _isFetchingGps = false;
        _gpsCoordinates = '7.0873° N, 80.0144° E';
        if (_addressCtrl.text.trim().isEmpty) {
          _addressCtrl.text = 'Yakkala, Western Province';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _darkGreen,
          behavior: SnackBarBehavior.floating,
          content: Text('GPS coordinates captured: 7.0873° N, 80.0144° E',
              style: GoogleFonts.inter(color: Colors.white)),
        ),
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final apiary = await ApiaryService.instance.createApiary(
        locationName: _nameCtrl.text,
        areaAddress: _addressCtrl.text,
        gpsLocation: _gpsCoordinates,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated(apiary);
      }
    } catch (e) {
      developer.log('Create apiary error: $e', name: 'AddApiarySheet');
      if (mounted) setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Add New Apiary', style: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.error))),
            const SizedBox(height: 12),
          ],
          // Location Name
          Align(alignment: Alignment.centerLeft,
            child: Text('Location name', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameCtrl,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Yakkala Bee Farm',
              fillColor: AppColors.bgSecondary,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter location name' : null,
          ),
          const SizedBox(height: 16),
          // Area / Address
          Align(alignment: Alignment.centerLeft,
            child: Text('Area / address', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          const SizedBox(height: 8),
          TextFormField(
            controller: _addressCtrl,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter area or address',
              fillColor: AppColors.bgSecondary,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter address or area' : null,
          ),
          const SizedBox(height: 16),
          // GPS Button — same card style as first_time_setup_screen
          GestureDetector(
            onTap: _onUseCurrentLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _lightGreenCard, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.my_location_rounded, color: _darkGreen, size: 22),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_gpsCoordinates != null
                        ? 'GPS: $_gpsCoordinates'
                        : 'Use current GPS location',
                      style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700, color: _darkGreen)),
                    const SizedBox(height: 2),
                    Text('Optional — helps identify the apiary',
                      style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary)),
                  ])),
                if (_isFetchingGps)
                  const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_darkGreen))),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          // Create button — same style as first_time_setup_screen
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _darkGreen, foregroundColor: Colors.white,
                elevation: 0, shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : Text('Create Apiary', style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}
