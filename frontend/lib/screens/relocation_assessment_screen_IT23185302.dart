import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../utils/theme.dart';
import '../widgets/image_source_sheet.dart';
import 'home_screen.dart';

/// Research Component IT23185302:
/// Wild Bee Colony Relocation Decision Support & Reporting System.
class RelocationAssessmentScreenIT23185302 extends StatefulWidget {
  const RelocationAssessmentScreenIT23185302({super.key});

  @override
  State<RelocationAssessmentScreenIT23185302> createState() =>
      _RelocationAssessmentScreenIT23185302State();
}

class _RelocationAssessmentScreenIT23185302State
    extends State<RelocationAssessmentScreenIT23185302> {
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  // 1. Photo state
  File? _pickedImage;

  // 2. Location state
  final _addressController =
      TextEditingController(text: '42 Flower Road, Colombo 07');
  String _gpsCoordinates = '6.9061° N, 79.8636° E';
  bool _isFetchingGps = false;

  // 3. Colony questions state
  String? _selectedLocation; // 'Roof', 'Wall', 'Tree', 'Other'
  final _otherLocationController = TextEditingController();

  String? _selectedHeight; // 'Below 2 m', '2–5 m', 'Above 5 m'
  String? _selectedInsideStructure; // 'Yes', 'No', 'Not sure'
  String? _selectedSafeAccess; // 'Yes', 'No', 'Not sure'

  bool _isSubmitting = false;

  @override
  void dispose() {
    _addressController.dispose();
    _otherLocationController.dispose();
    super.dispose();
  }

  // ── Image Picking ───────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (xFile != null) {
        setState(() {
          _pickedImage = File(xFile.path);
        });
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

  void _showImageSourceSheet() {
    ImageSourceSheet.show(
      context,
      onCamera: () => _pickImage(ImageSource.camera),
      onGallery: () => _pickImage(ImageSource.gallery),
    );
  }

  // ── GPS Auto-detection ──────────────────────────────────────
  Future<void> _refreshGps() async {
    setState(() => _isFetchingGps = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _gpsCoordinates = '6.9124° N, 79.8587° E';
      _isFetchingGps = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          'Location updated via GPS pin.',
          style: GoogleFonts.inter(
            color: AppColors.bgSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openPinAdjustDialog() {
    final latLngCtrl = TextEditingController(text: _gpsCoordinates);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Adjust Location Pin',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter exact coordinates or landmark description:',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: latLngCtrl,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bgPrimary,
                hintText: 'e.g. 6.9061° N, 79.8636° E',
                prefixIcon: const Icon(
                  Icons.edit_location_alt_rounded,
                  color: AppColors.hiveLow,
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.hiveLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              if (latLngCtrl.text.trim().isNotEmpty) {
                setState(() => _gpsCoordinates = latLngCtrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: Text(
              'Save Pin',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.bgSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form Validation & Submission ────────────────────────────
  void _handleSubmit() async {
    final missing = <String>[];
    if (_selectedLocation == null) missing.add('Where is the colony?');
    if (_selectedLocation == 'Other' &&
        _otherLocationController.text.trim().isEmpty) {
      missing.add('Specify "Other" colony location');
    }
    if (_selectedHeight == null) missing.add('Approximate height');
    if (_selectedInsideStructure == null) {
      missing.add('Is it inside a structure?');
    }
    if (_selectedSafeAccess == null) {
      missing.add('Can the area be safely accessed?');
    }

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          content: Text(
            'Please complete: ${missing.first}',
            style: GoogleFonts.inter(
              color: AppColors.bgSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Simulate backend submission & request creation
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final finalLocation = _selectedLocation == 'Other'
        ? 'Other (${_otherLocationController.text.trim()})'
        : _selectedLocation!;

    final requestId =
        '#REL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RelocationResultScreen(
          requestId: requestId,
          address: _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : 'Current GPS Location',
          gps: _gpsCoordinates,
          colonySpot: finalLocation,
          height: _selectedHeight!,
          insideStructure: _selectedInsideStructure!,
          safeAccess: _selectedSafeAccess!,
          imageFile: _pickedImage,
        ),
      ),
    );
  }

  // ── Bottom Nav Navigation ───────────────────────────────────
  void _onNavTapped(int index, bool isNormalUser) {
    final activeIndex = isNormalUser ? 1 : 2;
    if (index == activeIndex) return;

    if (index == 0) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
      return;
    }

    final labels = isNormalUser
        ? const ['Home', 'Report', 'Requests', 'Beekeepers']
        : const ['Home', 'Health', 'Relocate', 'Acoustic', 'Environment'];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${labels[index]} module will be available in the upcoming update.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.bgSecondary,
          ),
        ),
        backgroundColor: AppColors.panelBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNormalUser =
        AuthService.instance.currentUser?.isNormalUser ?? false;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        automaticallyImplyLeading: false, // No back button as requested
        centerTitle: true,
        title: Text(
          'Report Wild Colony',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header intro
                Text(
                  'Colony Relocation Request',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Provide colony details to connect with local registered beekeepers for ethical removal.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // ── SECTION 1: UPLOAD PHOTO ─────────────────────────
                _buildSectionHeader(
                  title: 'Upload Photo',
                  subtitle: 'Take a clear photo of the hive or nest entrance',
                  icon: Icons.camera_alt_outlined,
                ),
                const SizedBox(height: 12),
                _buildPhotoSection(),
                const SizedBox(height: 24),

                // ── SECTION 2: LOCATION ─────────────────────────────
                _buildSectionHeader(
                  title: 'Location',
                  subtitle: 'Colony address and GPS coordinates',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 12),
                _buildLocationCard(),
                const SizedBox(height: 24),

                // ── SECTION 3: WHERE IS THE BEE COLONY? ─────────────
                _buildSectionHeader(
                  title: 'Where is the bee colony?',
                  subtitle: 'Select where the bees have built their nest',
                  icon: Icons.home_work_outlined,
                ),
                const SizedBox(height: 12),
                _buildColonySpotGrid(),
                if (_selectedLocation == 'Other') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _otherLocationController,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Describe location (e.g. Garden shed, Chimney)',
                      filled: true,
                      fillColor: AppColors.bgSecondary,
                      prefixIcon: const Icon(
                        Icons.edit_note_rounded,
                        color: AppColors.hiveLow,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // ── SECTION 4: APPROXIMATE HEIGHT ───────────────────
                _buildSectionHeader(
                  title: 'Approximate height',
                  subtitle: 'Estimated vertical height from ground level',
                  icon: Icons.height_rounded,
                ),
                const SizedBox(height: 12),
                _buildHeightSelector(),
                const SizedBox(height: 24),

                // ── SECTION 5: INSIDE STRUCTURE? ────────────────────
                _buildSectionHeader(
                  title: 'Is it inside a structure?',
                  subtitle: 'Enclosed inside cavity, roof beam, or ceiling',
                  icon: Icons.domain_verification_outlined,
                ),
                const SizedBox(height: 12),
                _buildTripleChoice(
                  selectedValue: _selectedInsideStructure,
                  onChanged: (val) =>
                      setState(() => _selectedInsideStructure = val),
                ),
                const SizedBox(height: 24),

                // ── SECTION 6: CAN BE SAFELY ACCESSED? ───────────────
                _buildSectionHeader(
                  title: 'Can the area be safely accessed?',
                  subtitle: 'Free of power lines, sharp terrain, or hazards',
                  icon: Icons.health_and_safety_outlined,
                ),
                const SizedBox(height: 12),
                _buildTripleChoice(
                  selectedValue: _selectedSafeAccess,
                  onChanged: (val) => setState(() => _selectedSafeAccess = val),
                ),
                const SizedBox(height: 32),

                // ── SUBMIT BUTTON ───────────────────────────────────
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.hiveLow,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    child: _isSubmitting
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
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.send_rounded,
                                color: AppColors.bgSecondary,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Submit Report',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.bgSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
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
        currentIndex: isNormalUser ? 1 : 2,
        onTap: (i) => _onNavTapped(i, isNormalUser),
        items: isNormalUser
            ? const [
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
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_filled),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.monitor_heart_outlined),
                  label: 'Health',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.location_on_outlined),
                  activeIcon: Icon(Icons.location_on),
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
      ),
    );
  }

  // ── SUB-WIDGETS & SECTIONS ──────────────────────────────────

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.hiveLow.withValues(alpha: 0.12),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    if (_pickedImage != null) {
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
                height: 180,
                width: double.infinity,
                child: Image.file(
                  _pickedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Photo Attached',
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
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        onPressed: () => setState(() => _pickedImage = null),
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_a_photo_outlined,
              size: 24,
              color: AppColors.hiveLow,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Attach Colony Photo (Optional)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Helps beekeepers identify the species and prepare proper equipment',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 17),
                  label: Text(
                    'Take Photo',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _pickImage(ImageSource.camera),
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.photo_library_rounded, size: 17),
                  label: Text(
                    'Choose Gallery',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stylized interactive map preview card
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Stack(
              children: [
                // Stylized map grid pattern
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapCanvasPainter(),
                  ),
                ),
                // Center pin
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.hiveLow,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.hiveLow.withValues(alpha: 0.35),
                              blurRadius: 10,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.bgSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.panelBlack.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _gpsCoordinates,
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
                // Adjust pin button overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _openPinAdjustDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            size: 13,
                            color: AppColors.hiveLow,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Adjust Pin',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Address / Landmark',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: _isFetchingGps ? null : _refreshGps,
                      child: Row(
                        children: [
                          if (_isFetchingGps)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.hiveLow),
                              ),
                            )
                          else
                            const Icon(
                              Icons.my_location_rounded,
                              size: 13,
                              color: AppColors.hiveLow,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            _isFetchingGps
                                ? 'Detecting GPS...'
                                : 'Auto-detect GPS',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.hiveLow,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    hintText: 'Enter street name, house number, area',
                    filled: true,
                    fillColor: AppColors.bgPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
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

  Widget _buildColonySpotGrid() {
    final spots = [
      {'id': 'Roof', 'icon': Icons.roofing_rounded, 'label': 'Roof'},
      {'id': 'Wall', 'icon': Icons.apartment_rounded, 'label': 'Wall'},
      {'id': 'Tree', 'icon': Icons.park_rounded, 'label': 'Tree'},
      {'id': 'Other', 'icon': Icons.more_horiz_rounded, 'label': 'Other'},
    ];

    return Row(
      children: spots.map((spot) {
        final id = spot['id'] as String;
        final icon = spot['icon'] as IconData;
        final label = spot['label'] as String;
        final isSelected = _selectedLocation == id;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _selectedLocation = id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.bgElevated : AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.hiveLow : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: isSelected
                          ? AppColors.hiveLow
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeightSelector() {
    final options = [
      {'id': 'Below 2 m', 'label': 'Below 2 m', 'sub': 'Ground / Low'},
      {'id': '2–5 m', 'label': '2–5 m', 'sub': 'Standard ladder'},
      {'id': 'Above 5 m', 'label': 'Above 5 m', 'sub': 'High elevation'},
    ];

    return Row(
      children: options.map((opt) {
        final id = opt['id']!;
        final label = opt['label']!;
        final sub = opt['sub']!;
        final isSelected = _selectedHeight == id;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _selectedHeight = id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.bgElevated : AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.hiveLow : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTripleChoice({
    required String? selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    final choices = ['Yes', 'No', 'Not sure'];

    return Row(
      children: choices.map((choice) {
        final isSelected = selectedValue == choice;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onChanged(choice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.bgElevated : AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.hiveLow : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    choice,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
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

    // Subtle radial ring around center pin
    final ringPaint = Paint()
      ..color = AppColors.hiveLow.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), 24, ringPaint);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), 44, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── RELOCATION RESULT / STATUS SCREEN ─────────────────────────────
class RelocationResultScreen extends StatelessWidget {
  final String requestId;
  final String address;
  final String gps;
  final String colonySpot;
  final String height;
  final String insideStructure;
  final String safeAccess;
  final File? imageFile;

  const RelocationResultScreen({
    super.key,
    required this.requestId,
    required this.address,
    required this.gps,
    required this.colonySpot,
    required this.height,
    required this.insideStructure,
    required this.safeAccess,
    this.imageFile,
  });

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
          'Request Submitted',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success badge card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.hiveLow.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: AppColors.panelBlack,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.bgSecondary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Report Received!',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.panelBlack,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tracking ID: $requestId',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.panelBlack.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.panelBlack.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Status: Pending Beekeeper Assignment',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.panelBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Summary card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submitted Details',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Divider(height: 20, color: AppColors.border),
                    _buildSummaryRow('Location Spot', colonySpot),
                    _buildSummaryRow('Approx. Height', height),
                    _buildSummaryRow('Inside Structure', insideStructure),
                    _buildSummaryRow('Safe Access', safeAccess),
                    _buildSummaryRow('Address', address),
                    _buildSummaryRow('GPS Pin', gps),
                    if (imageFile != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Photo Preview',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              imageFile!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Safety Reminders
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.badgeLeafBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.badgeLeafFg.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppColors.badgeLeafFg,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Steps & Safety',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.badgeLeafFg,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A local registered beekeeper will review your report within 24 hours. Please do not attempt to disturb or spray the bees.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Action buttons
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.hiveLow,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  },
                  child: Text(
                    'Back to Home',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.bgSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          const RelocationAssessmentScreenIT23185302(),
                    ),
                  );
                },
                child: Text(
                  'Submit Another Report',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Typedef for general reference
typedef RelocationAssessmentScreen = RelocationAssessmentScreenIT23185302;
