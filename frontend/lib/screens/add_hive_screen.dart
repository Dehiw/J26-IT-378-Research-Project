import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/apiary_model.dart';
import '../services/apiary_service.dart';
import '../utils/theme.dart';

/// Add Hive Box screen — matches first_time_setup_screen.dart style.
/// No hive type / bee species. Frames: 1–12 via +/- stepper.
class AddHiveScreen extends StatefulWidget {
  final ApiaryModel apiary;
  const AddHiveScreen({super.key, required this.apiary});

  @override
  State<AddHiveScreen> createState() => _AddHiveScreenState();
}

class _AddHiveScreenState extends State<AddHiveScreen> {
  static const Color _darkGreen = Color(0xFF2C5E43);
  static const Color _lightGreenCard = Color(0xFFEAF2EC);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  int _numFrames = 8;
  bool _saving = false;
  String? _error;
  String _suggestedName = 'Hive Box #01';

  @override
  void initState() {
    super.initState();
    _loadSuggestedName();
  }

  Future<void> _loadSuggestedName() async {
    final name = await ApiaryService.instance
        .getNextHiveSuggestion(widget.apiary.id);
    if (mounted) {
      setState(() => _suggestedName = name);
      if (_nameCtrl.text.isEmpty) _nameCtrl.text = name;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: _darkGreen,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final hive = await ApiaryService.instance.createHive(
        apiaryId: widget.apiary.id,
        hiveName: _nameCtrl.text.trim().isEmpty
            ? _suggestedName : _nameCtrl.text.trim(),
        numFrames: _numFrames,
        hiveType: 'Langstroth',    // default — not shown to user
        beeSpecies: 'Apis cerana', // default — not shown to user
        installationDate: _dateCtrl.text.isNotEmpty ? _dateCtrl.text : null,
      );
      developer.log('Hive created: ${hive.name}', name: 'AddHiveScreen');
      if (mounted) Navigator.of(context).pop(hive);
    } catch (e) {
      developer.log('Create hive error: $e', name: 'AddHiveScreen');
      if (mounted) setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // Back row + Title
                    Row(children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.arrow_back,
                            color: AppColors.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Add Hive Box', style: GoogleFonts.inter(
                        fontSize: 26, fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary, letterSpacing: -0.5))),
                    ]),
                    const SizedBox(height: 6),
                    Text('Register a new hive box under this apiary',
                      style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
                    const SizedBox(height: 28),

                    // Selected apiary info card
                    _buildApiaryBanner(),
                    const SizedBox(height: 24),

                    // Error banner
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

                    // ── Hive Name ─────────────────────────────────
                    Text('Hive Box Name / Identifier', style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      style: GoogleFonts.inter(
                          fontSize: 15, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: _suggestedName,
                        fillColor: AppColors.bgSecondary,
                        filled: true,
                        helperText:
                            'Leave blank to use auto-generated: $_suggestedName',
                        helperStyle: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Number of Frames (1–12) ───────────────────
                    Text('Total Frames in Hive Box', style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
                    const SizedBox(height: 12),

                    // +/- Stepper — exactly like first_time_setup_screen.dart
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$_numFrames Frames', style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                          Row(children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: _darkGreen),
                              onPressed: _numFrames > 1
                                  ? () => setState(() => _numFrames -= 1)
                                  : null,
                            ),
                            Text('$_numFrames', style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: _darkGreen),
                              onPressed: _numFrames < 12
                                  ? () => setState(() => _numFrames += 1)
                                  : null,
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('$_numFrames frame records will be auto-generated.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 24),

                    // ── Installation Date (optional) ──────────────
                    Text('Installation Date (optional)', style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _dateCtrl,
                      readOnly: true,
                      onTap: _pickDate,
                      style: GoogleFonts.inter(
                          fontSize: 15, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Tap to select a date',
                        fillColor: AppColors.bgSecondary,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border)),
                        suffixIcon: _dateCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 16, color: AppColors.textMuted),
                                onPressed: () =>
                                    setState(() => _dateCtrl.clear()))
                            : const Icon(Icons.calendar_today_outlined,
                                size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Summary card — matches first_time_setup_screen review card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _lightGreenCard,
                        borderRadius: BorderRadius.circular(14)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ready to register this hive', style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: _darkGreen)),
                          const SizedBox(height: 4),
                          Text(
                            'Apiary: ${widget.apiary.locationName}\n'
                            'Hive: ${_nameCtrl.text.isNotEmpty ? _nameCtrl.text : _suggestedName} '
                            '($_numFrames frames)',
                            style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textPrimary,
                              height: 1.4)),
                        ]),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom CTA — same as first_time_setup_screen
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: SizedBox(
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)))
                    : Text('Create Hive', style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildApiaryBanner() {
    return GestureDetector(
      onTap: null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _lightGreenCard, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.location_on_rounded, color: _darkGreen, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selected Apiary', style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textSecondary)),
              Text(widget.apiary.locationName, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700, color: _darkGreen)),
            ])),
        ]),
      ),
    );
  }
}
