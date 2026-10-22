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
  final ApiaryService? apiaryService;
  const AddHiveScreen({super.key, required this.apiary, this.apiaryService});

  @override
  State<AddHiveScreen> createState() => _AddHiveScreenState();
}

class _AddHiveScreenState extends State<AddHiveScreen> {
  ApiaryService get _service => widget.apiaryService ?? ApiaryService.instance;

  static const Color _darkGreen = AppColors.accent3;
  static const Color _lightGreenCard = AppColors.badgeLeafBg;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  late ApiaryModel _apiary;
  List<ApiaryModel> _apiaries = [];
  bool _loadingApiaries = true;
  int _nameRequest = 0;
  String? _apiaryError;

  int _numFrames = 8;
  bool _saving = false;
  String? _error;
  String _suggestedName = 'Hive Box #01';

  @override
  void initState() {
    super.initState();
    _apiary = widget.apiary;
    _apiaries = [widget.apiary];
    _loadApiaries();
    _loadSuggestedName();
  }

  Future<void> _loadApiaries() async {
    try {
      final apiaries = await _service.fetchApiaries();
      if (!mounted) return;
      setState(() {
        _apiaries = apiaries;
        _loadingApiaries = false;
        if (apiaries.isNotEmpty) {
          _apiary = apiaries.firstWhere(
            (a) => a.id == _apiary.id,
            orElse: () => apiaries.first,
          );
        }
      });
      if (apiaries.isNotEmpty) await _loadSuggestedName();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingApiaries = false;
          _apiaryError = 'Other apiary locations could not be loaded. Using the original apiary.';
        });
      }
    }
  }

  Future<void> _loadSuggestedName() async {
    final request = ++_nameRequest;
    final oldSuggestion = _suggestedName;
    final name = await _service.getNextHiveSuggestion(_apiary.id);
    if (mounted && request == _nameRequest) {
      setState(() {
        _suggestedName = name;
        if (_nameCtrl.text.isEmpty || _nameCtrl.text == oldSuggestion) {
          _nameCtrl.text = name;
        }
      });
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
            onPrimary: AppColors.bgSecondary,
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
    if (_loadingApiaries ||
        _apiaries.isEmpty ||
        !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final hive = await _service.createHive(
        apiaryId: _apiary.id,
        hiveName: _nameCtrl.text.trim().isEmpty
            ? _suggestedName
            : _nameCtrl.text.trim(),
        numFrames: _numFrames,
        hiveType: 'Langstroth', // default — not shown to user
        beeSpecies: 'Apis cerana', // default — not shown to user
        installationDate: _dateCtrl.text.isNotEmpty ? _dateCtrl.text : null,
      );
      developer.log('Hive created: ${hive.name}', name: 'AddHiveScreen');
      if (mounted) Navigator.of(context).pop(hive);
    } catch (e) {
      developer.log('Create hive error: $e', name: 'AddHiveScreen');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
      }
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // Back row + Title
                      Row(
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Add Hive Box',
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Register a new hive box under this apiary',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _error!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Hive Name ─────────────────────────────────
                      Text(
                        'Hive Box Name / Identifier',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: _suggestedName,
                          fillColor: AppColors.bgSecondary,
                          filled: true,
                          helperText:
                              'Leave blank to use auto-generated: $_suggestedName',
                          helperStyle: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Number of Frames (1–12) ───────────────────
                      Text(
                        'Total Frames in Hive Box',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // +/- Stepper — exactly like first_time_setup_screen.dart
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgSecondary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$_numFrames Frames',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: _darkGreen,
                                  ),
                                  onPressed: _numFrames > 1
                                      ? () => setState(() => _numFrames -= 1)
                                      : null,
                                ),
                                Text(
                                  '$_numFrames',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: _darkGreen,
                                  ),
                                  onPressed: _numFrames < 12
                                      ? () => setState(() => _numFrames += 1)
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_numFrames frame records will be auto-generated.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Installation Date (optional) ──────────────
                      Text(
                        'Installation Date (optional)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _dateCtrl,
                        readOnly: true,
                        onTap: _pickDate,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tap to select a date',
                          fillColor: AppColors.bgSecondary,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          suffixIcon: _dateCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                  onPressed: () =>
                                      setState(() => _dateCtrl.clear()),
                                )
                              : const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Summary card — matches first_time_setup_screen review card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _lightGreenCard,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ready to register this hive',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _darkGreen,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Apiary: ${_apiary.locationName}\n'
                              'Hive: ${_nameCtrl.text.isNotEmpty ? _nameCtrl.text : _suggestedName} '
                              '($_numFrames frames)',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
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
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkGreen,
                    foregroundColor: AppColors.bgSecondary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _saving || _loadingApiaries || _apiaries.isEmpty
                      ? null
                      : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.bgSecondary,
                            ),
                          ),
                        )
                      : Text(
                          'Create Hive',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.bgSecondary,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiaryBanner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.badgeLeafBg,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'WHERE WILL THIS HIVE LIVE?',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.accent3,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingApiaries)
          const LinearProgressIndicator()
        else if (_apiaries.isEmpty)
          const Text('Create an apiary before adding a hive.')
        else
          DropdownButtonFormField<String>(
            key: ValueKey(_apiary.id),
            initialValue: _apiary.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Apiary location',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: _apiaries
                .map(
                  (a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(
                      a.locationName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (id) {
                    if (id == null) return;
                    setState(
                      () => _apiary = _apiaries.firstWhere((a) => a.id == id),
                    );
                    _loadSuggestedName();
                  },
          ),
        const SizedBox(height: 10),
        Text(
          _apiary.areaAddress,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Outdoor weather follows this apiary?s saved location. You can find this hive in Environment after saving.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.accent3,
            height: 1.5,
          ),
        ),
        if (_apiaryError != null)
          Text(
            _apiaryError!,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.warning),
          ),
      ],
    ),
  );
}
