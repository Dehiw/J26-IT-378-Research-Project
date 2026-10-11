import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// Dark hero panel from the reference: black square, gold ring, hive stack,
/// and four floating sensor badges. [variant] switches the centre motif
/// for the 3 onboarding pages (0 = hive, 1 = acoustics, 2 = forage).
class HeroArt extends StatelessWidget {
  final int variant;

  const HeroArt({super.key, this.variant = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      color: AppColors.panelBlack,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gold ring
          Container(
            width: 208,
            height: 208,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ring, width: 1.6),
            ),
          ),
          _centreMotif(),
          // Floating badges
          const Positioned(
            left: 12,
            top: 28,
            child: _Badge(
              bg: AppColors.badgeLeafBg,
              fg: AppColors.badgeLeafFg,
              icon: Icons.eco_outlined,
            ),
          ),
          const Positioned(
            right: 12,
            top: 18,
            child: _Badge(
              bg: AppColors.badgeWaveBg,
              fg: AppColors.badgeWaveFg,
              icon: Icons.graphic_eq,
            ),
          ),
          const Positioned(
            left: 12,
            bottom: 26,
            child: _Badge(
              bg: AppColors.badgeTempBg,
              fg: AppColors.badgeTempFg,
              icon: Icons.thermostat_outlined,
            ),
          ),
          const Positioned(
            right: 12,
            bottom: 34,
            child: _Badge(
              bg: AppColors.badgeBeeBg,
              fg: AppColors.badgeBeeFg,
              icon: Icons.bug_report_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _centreMotif() {
    switch (variant) {
      case 1:
        return _soundBars();
      case 2:
        return _forageMotif();
      default:
        return _hiveStack();
    }
  }

  /// Layered golden hive, echoing the reference illustration.
  Widget _hiveStack() {
    Widget bar(double width, Color color, {Widget? child}) {
      return Container(
        width: width,
        height: 27,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bar(64, AppColors.hiveTop),
        const SizedBox(height: 2),
        bar(102, const Color(0xFFE2B45A)),
        const SizedBox(height: 2),
        bar(122, AppColors.hiveMid),
        const SizedBox(height: 2),
        Stack(
          alignment: Alignment.center,
          children: [
            bar(134, const Color(0xFFC08C36)),
            const Positioned(left: 12, child: _BeeDot()),
            const Positioned(right: 26, top: 4, child: _BeeDot(size: 5)),
          ],
        ),
        const SizedBox(height: 2),
        bar(
          126,
          AppColors.hiveLow,
          child: Container(
            width: 22,
            height: 18,
            decoration: const BoxDecoration(
              color: AppColors.hiveDoor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
          ),
        ),
      ],
    );
  }

  /// Acoustic page motif: gold waveform bars.
  Widget _soundBars() {
    const heights = [36.0, 58.0, 84.0, 60.0, 96.0, 64.0, 44.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final h in heights)
          Container(
            width: 13,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.hiveTop,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
      ],
    );
  }

  /// Forage page motif: leaf pin over a gold disc.
  Widget _forageMotif() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.hiveTop.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
        ),
        const Icon(Icons.spa_outlined, size: 88, color: AppColors.hiveTop),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.place, size: 16, color: Colors.black),
          ),
        ),
      ],
    );
  }
}

class _BeeDot extends StatelessWidget {
  final double size;
  const _BeeDot({this.size = 7});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF3A2A12),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Color bg;
  final Color fg;
  final IconData icon;

  const _Badge({required this.bg, required this.fg, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: fg, size: 28),
    );
  }
}
