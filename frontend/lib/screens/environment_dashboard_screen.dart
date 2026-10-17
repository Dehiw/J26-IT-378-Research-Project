import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/theme.dart';
import '../widgets/main_bottom_nav.dart';
import 'forage_map_screen.dart';
import 'hive_telemetry_screen.dart';

class EnvironmentDashboardScreen extends StatelessWidget {
  const EnvironmentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    'Good morning 🐝',
                    style: _style(20, FontWeight.w800, AppColors.textPrimary),
                  ),
                ),
                const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 18),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: _cardDecoration(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 10,
                      color: AppColors.accent3,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'Colony 03 – Negombo',
                      style: _style(13, FontWeight.w600, AppColors.textPrimary),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accent3,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent3.withValues(alpha: .18),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Environmental Health Score',
                          style: _style(
                            14,
                            FontWeight.w500,
                            AppColors.bgPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Favorable Conditions',
                          style: _style(
                            17,
                            FontWeight.w700,
                            AppColors.bgPrimary,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '↗  Up 4 pts since last week',
                          style: _style(
                            12,
                            FontWeight.w500,
                            AppColors.bgPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 5),
                    ),
                    child: Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: _style(
                            28,
                            FontWeight.w800,
                            AppColors.bgPrimary,
                          ),
                          children: [
                            const TextSpan(text: '82\n'),
                            TextSpan(
                              text: '/ 100',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.thermostat_rounded,
                    label: 'Temperature',
                    value: '31°C',
                    note: 'Last 12 hrs',
                    color: AppColors.accent3,
                    onTap: () => _open(context, const HiveTelemetryScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.water_drop_outlined,
                    label: 'Humidity',
                    value: '64%',
                    note: 'Last 12 hrs',
                    color: AppColors.blue,
                    onTap: () => _open(context, const HiveTelemetryScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: _MetricCard(
                    icon: Icons.cloud_outlined,
                    label: 'Rainfall Risk',
                    value: 'Low',
                    note: '8% next 24 hrs',
                    color: AppColors.accent3,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: _MetricCard(
                    icon: Icons.eco_outlined,
                    label: 'Forage Diversity',
                    value: 'Moderate',
                    note: '6 species in 2 km',
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _open(context, const ForageMapScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent2.withValues(alpha: .09),
                  border: Border.all(
                    color: AppColors.accent2.withValues(alpha: .2),
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.accent2,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Insight',
                            style: _style(
                              12,
                              FontWeight.w700,
                              AppColors.accent2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Sample alert: pesticide exposure risk detected 2 km NE of hive.',
                            style: _style(
                              13,
                              FontWeight.w500,
                              AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.accent2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(
              'Forage & Risk Map',
              'Open map',
              () => _open(context, const ForageMapScreen()),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _open(context, const ForageMapScreen()),
              borderRadius: BorderRadius.circular(20),
              child: _MapPreview(),
            ),
            const SizedBox(height: 20),
            _sectionTitle(
              'Predictive Alerts',
              'See all',
              () => _open(context, const HiveTelemetryScreen()),
            ),
            const SizedBox(height: 10),
            _AlertRow(
              icon: Icons.thermostat_rounded,
              title: 'Temperature stable',
              subtitle: 'Sample telemetry · Hive #03',
              color: AppColors.accent3,
            ),
            const SizedBox(height: 24),
            Text(
              'Sample dashboard values',
              style: _style(11, FontWeight.w500, AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: MainBottomNav(
      currentIndex: 4,
      onTap: (i) => _navigateTab(context, i),
    ),
  );
}

TextStyle _style(double size, FontWeight weight, Color color) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);
BoxDecoration _cardDecoration() => BoxDecoration(
  color: AppColors.bgSecondary,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: AppColors.border),
  boxShadow: [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: .06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
);
void _open(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
void _navigateTab(BuildContext context, int i) {
  if (i == 1) _open(context, const HiveTelemetryScreen());
  if (i == 2) _open(context, const ForageMapScreen());
  if (i == 0) Navigator.maybePop(context);
}

Widget _sectionTitle(String title, String action, VoidCallback onTap) => Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(title, style: _style(17, FontWeight.w800, AppColors.textPrimary)),
    TextButton(
      onPressed: onTap,
      child: Text(action, style: _style(12, FontWeight.w700, AppColors.blue)),
    ),
  ],
);

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label, value, note;
  final Color color;
  final VoidCallback? onTap;
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    required this.color,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _style(12, FontWeight.w500, AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: _style(23, FontWeight.w800, AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: _style(11, FontWeight.w500, AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _MapPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 156,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _MapPainter())),
        const Positioned(
          left: 20,
          bottom: 12,
          child: _MapTag(text: '3 km foraging radius'),
        ),
        const Center(
          child: Icon(Icons.hexagon_rounded, size: 34, color: AppColors.accent),
        ),
        const Positioned(
          right: 14,
          top: 12,
          child: Icon(
            Icons.warning_rounded,
            size: 23,
            color: AppColors.accent2,
          ),
        ),
      ],
    ),
  );
}

class _MapTag extends StatelessWidget {
  final String text;
  const _MapTag({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: _style(10, FontWeight.w700, AppColors.textPrimary),
    ),
  );
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    p.color = AppColors.badgeLeafBg;
    canvas.drawLine(
      Offset(-10, size.height * .72),
      Offset(size.width * .35, size.height * .5),
      p,
    );
    canvas.drawLine(
      Offset(size.width * .35, size.height * .5),
      Offset(size.width + 12, size.height * .35),
      p,
    );
    p
      ..color = AppColors.bgPrimary
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(0, size.height * .3),
      Offset(size.width, size.height * .75),
      p,
    );
    p
      ..color = AppColors.accent3.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(size.width * .5, size.height * .5),
      size.height * .38,
      p,
    );
    p
      ..style = PaintingStyle.fill
      ..color = AppColors.accent2;
    canvas.drawCircle(Offset(size.width * .68, size.height * .26), 6, p);
    canvas.drawCircle(Offset(size.width * .32, size.height * .72), 6, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AlertRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _AlertRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _cardDecoration(),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _style(13, FontWeight.w700, AppColors.textPrimary),
              ),
              Text(
                subtitle,
                style: _style(11, FontWeight.w500, AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      ],
    ),
  );
}
