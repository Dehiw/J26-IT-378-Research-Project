import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/apiary_model.dart';
import '../services/apiary_service.dart';
import '../utils/theme.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/main_bottom_nav.dart';
import 'IT23183186_environment_dashboard_screen.dart';
import 'IT23185302_repositioning_results_screen.dart';

/// Research Component IT23185302:
/// Hive Repositioning — select an apiary + hive box and upload a land photo
/// to analyze candidate zones within the same apiary.
class HiveRepositioningScreenIT23185302 extends StatefulWidget {
  const HiveRepositioningScreenIT23185302({super.key});

  @override
  State<HiveRepositioningScreenIT23185302> createState() =>
      _HiveRepositioningScreenIT23185302State();
}

class _HiveRepositioningScreenIT23185302State
    extends State<HiveRepositioningScreenIT23185302> {
  final int _currentNavIndex = 2; // Relocate is tab index 2
  final _picker = ImagePicker();

  // Apiaries
  bool _loadingApiaries = true;
  String? _apiaryError;
  List<ApiaryModel> _apiaries = [];
  ApiaryModel? _selectedApiary;

  // Hive boxes of the selected apiary
  bool _loadingHives = false;
  String? _hiveError;
  List<HiveModel> _hives = [];
  HiveModel? _selectedHive;

  // Land photo
  File? _landPhoto;

  bool get _canAnalyze =>
      _selectedApiary != null && _selectedHive != null && _landPhoto != null;

  @override
  void initState() {
    super.initState();
    _loadApiaries();
  }

  // ── Data loading ──────────────────────────────────────────────────

  Future<void> _loadApiaries() async {
    setState(() {
      _loadingApiaries = true;
      _apiaryError = null;
    });
    try {
      final list = await ApiaryService.instance.fetchApiaries();
      if (!mounted) return;
      final preselected = ApiaryService.instance.selectedApiary;
      ApiaryModel? initial;
      if (preselected != null) {
        for (final a in list) {
          if (a.id == preselected.id) initial = a;
        }
      }
      setState(() {
        _apiaries = list;
        _loadingApiaries = false;
      });
      if (initial != null) _onApiaryChanged(initial);
    } catch (e) {
      developer.log('Error loading apiaries: $e', name: 'HiveRepositioning');
      if (!mounted) return;
      setState(() {
        _loadingApiaries = false;
        _apiaryError = 'Could not load your apiaries. Pull to retry.';
      });
    }
  }

  Future<void> _onApiaryChanged(ApiaryModel? apiary) async {
    if (apiary == null || apiary.id == _selectedApiary?.id) return;
    setState(() {
      _selectedApiary = apiary;
      _selectedHive = null;
      _hives = [];
      _hiveError = null;
      _loadingHives = true;
    });
    try {
      final hives = await ApiaryService.instance.fetchHives(apiary.id);
      if (!mounted || _selectedApiary?.id != apiary.id) return;
      setState(() {
        _hives = hives;
        _loadingHives = false;
      });
    } catch (e) {
      developer.log('Error loading hives: $e', name: 'HiveRepositioning');
      if (!mounted || _selectedApiary?.id != apiary.id) return;
      setState(() {
        _loadingHives = false;
        _hiveError = 'Could not load hive boxes for this apiary.';
      });
    }
  }

  // ── Image picking ─────────────────────────────────────────────────

  void _showImageSourceSheet() {
    ImageSourceSheet.show(
      context,
      onCamera: () => _pickImage(ImageSource.camera),
      onGallery: () => _pickImage(ImageSource.gallery),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (xFile != null && mounted) {
        setState(() => _landPhoto = File(xFile.path));
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not open image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Actions ───────────────────────────────────────────────────────

  void _analyzeLand() {
    if (!_canAnalyze) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepositioningResultsScreenIT23185302(
          apiary: _selectedApiary!,
          hive: _selectedHive!,
          landPhoto: _landPhoto!,
        ),
      ),
    );
  }

  void _onNavTapped(int index) {
    if (index == _currentNavIndex) {
      // Back to the Relocation dashboard.
      Navigator.of(context).pop();
      return;
    }
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    _showSnack('Module tab $index will be available in the upcoming update.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
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

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Hive Repositioning',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.hiveLow,
          onRefresh: _loadApiaries,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Upload a photo of your apiary land to find better hive positions within the same apiary.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                _buildStepLabel(1, 'Select Apiary'),
                const SizedBox(height: 10),
                _buildApiaryDropdown(),

                const SizedBox(height: 24),
                _buildStepLabel(2, 'Select Hive Box'),
                const SizedBox(height: 10),
                _buildHiveDropdown(),

                const SizedBox(height: 24),
                _buildStepLabel(3, 'Upload Apiary Land Photo'),
                const SizedBox(height: 10),
                _buildPhotoSection(),

                const SizedBox(height: 28),
                _buildAnalyzeButton(),
                const SizedBox(height: 32),
              ],
            ).animate().fadeIn(duration: 350.ms),
          ),
        ),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: _currentNavIndex,
        onTap: _onNavTapped,
      ),
    );
  }

  Widget _buildStepLabel(int step, String label) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            gradient: AppColors.accentGradient,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$step',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.bgSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Step 1: Apiary ────────────────────────────────────────────────

  Widget _buildApiaryDropdown() {
    if (_loadingApiaries) {
      return const _FieldShell(child: _InlineLoader(label: 'Loading apiaries…'));
    }
    if (_apiaryError != null) {
      return _FieldShell(
        child: _InlineMessage(
          icon: Icons.cloud_off_rounded,
          color: AppColors.error,
          message: _apiaryError!,
          actionLabel: 'Retry',
          onAction: _loadApiaries,
        ),
      );
    }
    if (_apiaries.isEmpty) {
      return const _FieldShell(
        child: _InlineMessage(
          icon: Icons.location_off_outlined,
          color: AppColors.warning,
          message: 'No registered apiaries found. Add an apiary first.',
        ),
      );
    }
    return _FieldShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ApiaryModel>(
          isExpanded: true,
          value: _selectedApiary,
          hint: _dropdownHint('Choose an apiary'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
          dropdownColor: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          items: _apiaries
              .map((a) => DropdownMenuItem<ApiaryModel>(
                    value: a,
                    child: _dropdownItem(
                      Icons.location_on_outlined,
                      a.locationName,
                      a.areaAddress,
                    ),
                  ))
              .toList(),
          onChanged: _onApiaryChanged,
        ),
      ),
    );
  }

  // ── Step 2: Hive box ──────────────────────────────────────────────

  Widget _buildHiveDropdown() {
    if (_selectedApiary == null) {
      return const _FieldShell(
        child: _InlineMessage(
          icon: Icons.info_outline_rounded,
          color: AppColors.textSecondary,
          message: 'Select an apiary to see its hive boxes.',
        ),
      );
    }
    if (_loadingHives) {
      return const _FieldShell(child: _InlineLoader(label: 'Loading hive boxes…'));
    }
    if (_hiveError != null) {
      return _FieldShell(
        child: _InlineMessage(
          icon: Icons.cloud_off_rounded,
          color: AppColors.error,
          message: _hiveError!,
          actionLabel: 'Retry',
          onAction: () {
            final apiary = _selectedApiary!;
            _selectedApiary = null;
            _onApiaryChanged(apiary);
          },
        ),
      );
    }
    if (_hives.isEmpty) {
      return const _FieldShell(
        child: _InlineMessage(
          icon: Icons.inventory_2_outlined,
          color: AppColors.warning,
          message: 'This apiary has no hive boxes yet.',
        ),
      );
    }
    return _FieldShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<HiveModel>(
          isExpanded: true,
          value: _selectedHive,
          hint: _dropdownHint('Choose a hive box'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
          dropdownColor: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          items: _hives
              .map((h) => DropdownMenuItem<HiveModel>(
                    value: h,
                    child: _dropdownItem(
                      Icons.hive_outlined,
                      h.name,
                      '${h.hiveType} • ${h.numFrames} frames',
                    ),
                  ))
              .toList(),
          onChanged: (h) => setState(() => _selectedHive = h),
        ),
      ),
    );
  }

  Widget _dropdownHint(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      );

  Widget _dropdownItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.hiveLow),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 3: Photo ─────────────────────────────────────────────────

  Widget _buildPhotoSection() {
    if (_landPhoto != null) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: Image.file(_landPhoto!, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Land Photo Attached',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          'Retake',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.hiveLow,
                          ),
                        ),
                        onPressed: _showImageSourceSheet,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.error),
                        tooltip: 'Remove photo',
                        onPressed: () => setState(() => _landPhoto = null),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _PhotoSourceButton(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            subtitle: 'Take a photo',
            color: AppColors.accent,
            onTap: () => _pickImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PhotoSourceButton(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            subtitle: 'Pick from library',
            color: AppColors.blue,
            onTap: () => _pickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  // ── Analyze button ────────────────────────────────────────────────

  Widget _buildAnalyzeButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _canAnalyze ? _analyzeLand : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textPrimary,
              disabledBackgroundColor: AppColors.bgElevated,
              disabledForegroundColor: AppColors.textSecondary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.travel_explore_rounded, size: 20),
            label: Text(
              'Analyze Land',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (!_canAnalyze) ...[
          const SizedBox(height: 8),
          Text(
            'Select an apiary, a hive box, and upload a land photo to continue.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Private widgets ─────────────────────────────────────────────────

class _FieldShell extends StatelessWidget {
  final Widget child;
  const _FieldShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _InlineLoader extends StatelessWidget {
  final String label;
  const _InlineLoader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.hiveLow),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InlineMessage({
    required this.icon,
    required this.color,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.hiveLow,
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PhotoSourceButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
