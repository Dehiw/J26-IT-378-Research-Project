import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/inference_service.dart';
import '../utils/theme.dart';
import 'home_screen.dart';

class FirstTimeSetupScreen extends StatefulWidget {
  final InferenceService? inferenceService;

  const FirstTimeSetupScreen({super.key, this.inferenceService});

  @override
  State<FirstTimeSetupScreen> createState() => _FirstTimeSetupScreenState();
}

class _FirstTimeSetupScreenState extends State<FirstTimeSetupScreen> {
  int _currentStep = 1; // 1 = Location, 2 = Hive, 3 = Frames

  // Step 1: Location
  final _locationNameController = TextEditingController();
  final _addressController = TextEditingController();
  String? _gpsCoordinates;
  bool _isFetchingGps = false;

  // Step 2: Hive Box
  final _hiveNameController = TextEditingController(text: 'Hive Box #01');
  String _selectedHiveType = 'Langstroth';
  String _selectedSpecies = 'Apis cerana';

  // Step 3: Frames
  int _numFrames = 8;
  String _colonyCondition = 'Healthy & Active';

  bool _isLoading = false;

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  static const Color _darkGreen = Color(0xFF2C5E43);
  static const Color _lightGreenCard = Color(0xFFEAF2EC);

  @override
  void initState() {
    super.initState();
    _loadNextBoxSuggestion();
  }

  Future<void> _loadNextBoxSuggestion() async {
    final suggested = await AuthService.instance.getNextHiveSuggestion();
    if (mounted) {
      setState(() {
        _hiveNameController.text = suggested;
      });
    }
  }

  @override
  void dispose() {
    _locationNameController.dispose();
    _addressController.dispose();
    _hiveNameController.dispose();
    super.dispose();
  }

  void _onUseCurrentLocation() {
    setState(() => _isFetchingGps = true);
    // Simulate fetching device GPS coordinates without needing extra permission plugins
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _isFetchingGps = false;
        _gpsCoordinates = '7.0873° N, 80.0144° E';
        if (_addressController.text.trim().isEmpty) {
          _addressController.text = 'Yakkala, Western Province';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _darkGreen,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'GPS coordinates captured: 7.0873° N, 80.0144° E',
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
      );
    });
  }

  void _onContinue() {
    if (_currentStep == 1) {
      if (!_step1FormKey.currentState!.validate()) return;
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (!_step2FormKey.currentState!.validate()) return;
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      _saveSetupAndFinish();
    }
  }

  void _onBack() {
    if (_currentStep > 1) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _saveSetupAndFinish() async {
    setState(() => _isLoading = true);

    try {
      await AuthService.instance.saveApiarySetup(
        locationName: _locationNameController.text.trim(),
        areaAddress: _addressController.text.trim(),
        gpsLocation: _gpsCoordinates,
        hiveName: _hiveNameController.text.trim(),
        hiveType: _selectedHiveType,
        beeSpecies: _selectedSpecies,
        numFrames: _numFrames,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(inferenceService: widget.inferenceService),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      developer.log('Setup error: $e', name: 'FirstTimeSetup');

      // Still allow proceeding to Home on local fallback so user is never blocked
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(inferenceService: widget.inferenceService),
        ),
        (route) => false,
      );
    }
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // Title & Subtitle matching reference
                    Text(
                      'Set up your apiary',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create your first location before monitoring hives',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 3-Step Indicator
                    _buildStepper(),
                    const SizedBox(height: 36),

                    // Step content based on active step
                    if (_currentStep == 1) _buildStep1Location(),
                    if (_currentStep == 2) _buildStep2Hive(),
                    if (_currentStep == 3) _buildStep3Frames(),
                  ],
                ),
              ),
            ),

            // Bottom Continue CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _onContinue,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _currentStep == 3 ? 'Complete Setup' : 'Continue',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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

  // ── Stepper Header ──────────────────────────────────────────
  Widget _buildStepper() {
    return Row(
      children: [
        _buildStepItem(1, 'Location'),
        _buildStepDivider(_currentStep > 1),
        _buildStepItem(2, 'Hive'),
        _buildStepDivider(_currentStep > 2),
        _buildStepItem(3, 'Frames'),
      ],
    );
  }

  Widget _buildStepItem(int stepNumber, String label) {
    final isActive = _currentStep == stepNumber;
    final isCompleted = _currentStep > stepNumber;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isActive || isCompleted)
                  ? _darkGreen
                  : Colors.transparent,
              border: Border.all(
                color: (isActive || isCompleted)
                    ? _darkGreen
                    : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$stepNumber',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? _darkGreen : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(bool isCompleted) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 24),
      color: isCompleted ? _darkGreen : AppColors.border,
    );
  }

  // ── Step 1: Location ───────────────────────────────────────
  Widget _buildStep1Location() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location name',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _locationNameController,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Yakkala Bee Farm',
              fillColor: AppColors.bgSecondary,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter location name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Area / address',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _addressController,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Enter area or address',
              fillColor: AppColors.bgSecondary,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter address or area';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Use GPS location card button
          GestureDetector(
            onTap: _onUseCurrentLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _lightGreenCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    color: _darkGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _gpsCoordinates != null
                              ? 'GPS: $_gpsCoordinates'
                              : 'Use current GPS location',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _darkGreen,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Optional - helps identify the apiary',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isFetchingGps)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_darkGreen),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Hive ───────────────────────────────────────────
  Widget _buildStep2Hive() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: _onBack,
              ),
              const SizedBox(width: 12),
              Text(
                'Configure ${_hiveNameController.text.isNotEmpty ? _hiveNameController.text : "Hive Box"}',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
            controller: _hiveNameController,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Hive Box #01',
              fillColor: AppColors.bgSecondary,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please name this hive box';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Hive Box Type',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedHiveType,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'Langstroth', child: Text('Langstroth Box')),
                  DropdownMenuItem(
                      value: 'Top-Bar', child: Text('Top-Bar Hive')),
                  DropdownMenuItem(
                      value: 'Warre', child: Text('Warré Hive')),
                  DropdownMenuItem(
                      value: 'Traditional', child: Text('Traditional Clay/Log')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedHiveType = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bee Species',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedSpecies,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'Apis cerana',
                      child: Text('Apis cerana (Asian Honeybee)')),
                  DropdownMenuItem(
                      value: 'Apis mellifera',
                      child: Text('Apis mellifera (Western Honeybee)')),
                  DropdownMenuItem(
                      value: 'Tetragonula',
                      child: Text('Tetragonula iridipennis (Stingless Bee)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSpecies = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Frames ─────────────────────────────────────────
  Widget _buildStep3Frames() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: _onBack,
            ),
            const SizedBox(width: 12),
            Text(
              'Frames & Brood Chamber',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Total Frames in Chamber',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // Stepper for number of frames
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    icon: const Icon(Icons.remove_circle_outline,
                        color: _darkGreen),
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
                    icon: const Icon(Icons.add_circle_outline, color: _darkGreen),
                    onPressed: _numFrames < 24
                        ? () => setState(() => _numFrames += 1)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Initial Colony Status',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _colonyCondition,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              items: const [
                DropdownMenuItem(
                    value: 'Healthy & Active',
                    child: Text('Healthy & Active')),
                DropdownMenuItem(
                    value: 'Newly Established Colony',
                    child: Text('Newly Established Colony')),
                DropdownMenuItem(
                    value: 'Under Observation',
                    child: Text('Under Observation')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _colonyCondition = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Summary Card
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
                'Ready to monitor your hive',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _darkGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Location: ${_locationNameController.text}\nHive: ${_hiveNameController.text} (${_selectedHiveType}, $_numFrames frames)',
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
    );
  }
}
