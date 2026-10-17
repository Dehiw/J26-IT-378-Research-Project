import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/theme.dart';
import '../widgets/main_bottom_nav.dart';
import 'IT23183186_environment_dashboard_screen.dart';
import 'IT23183186_hive_telemetry_screen.dart';

class ForageMapScreen extends StatelessWidget {
  const ForageMapScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    body: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _ForageMapPainter())),
          Positioned(
            left: 16,
            top: 12,
            child: CircleAvatar(
              backgroundColor: AppColors.bgSecondary,
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            left: 78,
            right: 68,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgPrimary,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: .12),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Text(
                  'Forage & Risk Map',
                  style: _text(16, FontWeight.w800, AppColors.textPrimary),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 86,
            child: Column(
              children: [
                _MapButton(
                  icon: Icons.layers_outlined,
                  onTap: () => _message(context, 'Map layers'),
                ),
                const SizedBox(height: 10),
                _MapButton(
                  icon: Icons.my_location_rounded,
                  onTap: () =>
                      _message(context, 'Showing sample hive location'),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: .12),
                    blurRadius: 18,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Foraging Radius Insights',
                    style: _text(19, FontWeight.w800, AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      _Legend(
                        color: AppColors.accent3,
                        label: 'Safe forage area',
                      ),
                      SizedBox(width: 14),
                      _Legend(color: AppColors.accent2, label: 'Risk zone'),
                      SizedBox(width: 14),
                      _Legend(color: AppColors.accent, label: 'Hive location'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _InsightRow(
                    icon: Icons.grass_rounded,
                    title: 'Agricultural land',
                    value: '45%',
                    subtitle: 'Coconut, banana',
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 9),
                  const _InsightRow(
                    icon: Icons.local_florist_outlined,
                    title: 'Native flora',
                    value: '30%',
                    subtitle: 'Scrub & mangrove',
                    color: AppColors.accent3,
                  ),
                  const SizedBox(height: 9),
                  const _InsightRow(
                    icon: Icons.warning_amber_rounded,
                    title: 'Pesticide-treated crops',
                    value: '12%',
                    subtitle: 'Sample risk area',
                    color: AppColors.accent2,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        _message(context, 'Full report is not connected yet'),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      'View Full Report',
                      style: _text(13, FontWeight.w700, AppColors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: MainBottomNav(
      currentIndex: 2,
      onTap: (i) => _navigate(context, i),
    ),
  );
}

void _message(BuildContext c, String s) => ScaffoldMessenger.of(c).showSnackBar(
  SnackBar(
    content: Text(s, style: _text(13, FontWeight.w500, AppColors.bgSecondary)),
    backgroundColor: AppColors.panelBlack,
    behavior: SnackBarBehavior.floating,
  ),
);
void _navigate(BuildContext c, int i) {
  if (i == 0) Navigator.maybePop(c);
  if (i == 1)
    Navigator.push(
      c,
      MaterialPageRoute<void>(builder: (_) => const HiveTelemetryScreen()),
    );
  if (i == 4)
    Navigator.push(
      c,
      MaterialPageRoute<void>(
        builder: (_) => const EnvironmentDashboardScreen(),
      ),
    );
}

TextStyle _text(double s, FontWeight w, Color c) =>
    GoogleFonts.inter(fontSize: s, fontWeight: w, color: c);

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext c) => Material(
    color: AppColors.bgSecondary,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Icon(icon, color: AppColors.textPrimary),
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext c) => Expanded(
    child: Row(
      children: [
        Icon(Icons.circle, size: 9, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(9, FontWeight.w500, AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String title, value, subtitle;
  final Color color;
  const _InsightRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _text(12, FontWeight.w700, AppColors.textPrimary),
              ),
              Text(
                subtitle,
                style: _text(10, FontWeight.w500, AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Text(value, style: _text(15, FontWeight.w800, color)),
      ],
    ),
  );
}

class _ForageMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.bgElevated);
    final p = Paint()..style = PaintingStyle.fill;
    final blocks = [
      (
        AppColors.badgeLeafBg,
        Rect.fromLTWH(
          -20,
          size.height * .18,
          size.width * .52,
          size.height * .28,
        ),
      ),
      (
        AppColors.accent3.withValues(alpha: .3),
        Rect.fromLTWH(
          size.width * .61,
          size.height * .15,
          size.width * .48,
          size.height * .38,
        ),
      ),
      (
        AppColors.badgeBeeBg,
        Rect.fromLTWH(
          size.width * .03,
          size.height * .66,
          size.width * .42,
          size.height * .3,
        ),
      ),
      (
        AppColors.bgPrimary,
        Rect.fromLTWH(
          size.width * .59,
          size.height * .64,
          size.width * .5,
          size.height * .35,
        ),
      ),
    ];
    for (final b in blocks) {
      p.color = b.$1;
      canvas.drawRect(b.$2, p);
    }
    final roads = Paint()
      ..color = AppColors.bgPrimary
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-10, size.height * .36),
      Offset(size.width * .43, size.height * .56),
      roads,
    );
    canvas.drawLine(
      Offset(size.width * .43, size.height * .56),
      Offset(size.width + 10, size.height * .41),
      roads,
    );
    canvas.drawLine(
      Offset(size.width * .62, 0),
      Offset(size.width * .68, size.height * .72),
      roads,
    );
    canvas.drawLine(
      Offset(0, size.height * .73),
      Offset(size.width * .84, size.height * .28),
      roads,
    );
    final ring = Paint()
      ..color = AppColors.accent3.withValues(alpha: .6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(size.width * .5, size.height * .47),
      size.width * .38,
      ring,
    );
    final risk = Paint()..color = AppColors.accent2;
    canvas.drawCircle(Offset(size.width * .72, size.height * .38), 8, risk);
    canvas.drawCircle(Offset(size.width * .33, size.height * .62), 8, risk);
    final hive = Paint()..color = AppColors.accent;
    final center = Offset(size.width * .5, size.height * .47);
    final path = Path()
      ..moveTo(center.dx, center.dy - 16)
      ..lineTo(center.dx + 14, center.dy - 8)
      ..lineTo(center.dx + 14, center.dy + 8)
      ..lineTo(center.dx, center.dy + 16)
      ..lineTo(center.dx - 14, center.dy + 8)
      ..lineTo(center.dx - 14, center.dy - 8)
      ..close();
    canvas.drawPath(path, hive);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.bgSecondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
