import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/theme.dart';
import '../services/inference_service.dart';
import '../widgets/hero_art.dart';
import 'home_screen.dart';

/// 3-page onboarding flow matching the reference (cream bg, black hero panel,
/// honey-gold CTA). Page 0 reproduces the screenshot 1:1.
class OnboardingScreen extends StatefulWidget {
  final InferenceService? inferenceService;
  const OnboardingScreen({super.key, this.inferenceService});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      title: "Understand Your Hive's\nEnvironment",
      body: "Real-time IoT telemetry, acoustic health checks, and forage "
          "mapping — all in one place.",
    ),
    (
      title: "Hear What Your\nBees Are Saying",
      body: "Acoustic health checks flag stress, swarming and queen loss "
          "days before you can see it.",
    ),
    (
      title: "Find Forage,\nRelocate with Care",
      body: "Map wild hives and forage zones, then plan safe, "
          "guided relocations.",
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            HomeScreen(inferenceService: widget.inferenceService),
      ),
    );
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _goHome();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: brand left, skip right (as in reference)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hive Sense',
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: _goHome,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      children: [
                        HeroArt(variant: i),
                        const SizedBox(height: 36),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: i == _page ? 30 : 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.accent
                          : AppColors.textMuted,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            // CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(
                      _page == _pages.length - 1 ? 'Get Started' : 'Next'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Footer docs link (as in reference)
            RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 14),
                children: const [
                  TextSpan(text: 'Want to learn more ?  '),
                  TextSpan(
                    text: 'View Documentations',
                    style: TextStyle(
                      color: Color(0xFF2E3A4D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
