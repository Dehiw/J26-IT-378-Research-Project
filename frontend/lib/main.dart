import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'utils/theme.dart';
import 'services/inference_service.dart';
import 'screens/onboarding_screen.dart';

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
    try {
      await _inferenceService.init();
      if (mounted) {
        setState(() {
          _loading = false;
          _readyService = _inferenceService;
        });
      }
    } catch (_) {
      // Model files not bundled yet — continue in demo mode.
      if (mounted) setState(() => _loading = false);
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
            ),
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
            ),
            const SizedBox(height: 8),
            Text(
              'Loading hive-health model…',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
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
            ),
          ],
        ),
      ),
    );
  }
}
