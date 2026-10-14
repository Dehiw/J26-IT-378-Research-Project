import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'utils/theme.dart';
import 'services/auth_service.dart';
import 'services/inference_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait (mobile app)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.bgPrimary,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const HiveSenseApp());
}

class HiveSenseApp extends StatelessWidget {
  const HiveSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hive Sense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AppLoader(),
    );
  }
}

/// Tries to initialise the ONNX inference service before showing the app.
/// Unlike a hard-fail loader, a missing model degrades gracefully to demo
/// mode (HomeScreen with inferenceService: null) so the UI is usable
/// before the .onnx files are bundled.
class _AppLoader extends StatefulWidget {
  const _AppLoader();

  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  final InferenceService _inferenceService = InferenceService();
  bool _loading = true;
  InferenceService? _readyService;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Keep splash screen visible for at least 2.2 seconds for branding
    final splashTimer = Future.delayed(const Duration(milliseconds: 2200));

    try {
      await _inferenceService.init();
      _readyService = _inferenceService;
    } catch (_) {
      // Model files not bundled yet — continue in demo mode.
    }

    await splashTimer;

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    if (_readyService != null) _inferenceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();

    // App always begins with the 3 Onboarding Pages
    return OnboardingScreen(
      key: ValueKey(_readyService != null),
      inferenceService: _readyService,
    );
  }
}

// ── Splash ───────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.hive_outlined,
                color: Color(0xFF211D16),
                size: 44,
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0)),
            const SizedBox(height: 28),
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.accentGradient.createShader(bounds),
              child: Text(
                'Hive Sense',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: 8),
            Text(
              'Smart Beehive Intelligence',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ).animate().fadeIn(delay: 350.ms, duration: 500.ms),
            const SizedBox(height: 40),
            SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
              ),
            ).animate().fadeIn(delay: 450.ms, duration: 500.ms),
          ],
        ),
      ),
    );
  }
}
