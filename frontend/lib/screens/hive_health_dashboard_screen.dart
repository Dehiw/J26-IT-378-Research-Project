import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/inference_service.dart';
import '../utils/theme.dart';
import '../widgets/bee_illustration.dart';
import 'it23136274_sensor_trends_screen.dart';
import 'scanner_screen.dart';

/// Hive Health Dashboard Screen (Live Monitoring)
/// Displays overall colony health banner, live ESP32 sensor telemetry
/// (Temperature, Humidity, Hive Weight, Bee Activity), and detailed trends.
class HiveHealthDashboardScreen extends StatefulWidget {
  final String hiveId;
  final String hiveName;
  final String apiaryName;
  final String status;
  final int boxNumber;
  final int numFrames;
  final InferenceService? inferenceService;

  const HiveHealthDashboardScreen({
    super.key,
    this.hiveId = 'hive-01',
    this.hiveName = 'Hive 01',
    this.apiaryName = 'Yakkala Apiary',
    this.status = 'Healthy',
    this.boxNumber = 1,
    this.numFrames = 10,
    this.inferenceService,
  });

  @override
  State<HiveHealthDashboardScreen> createState() => _HiveHealthDashboardScreenState();
}

class _HiveHealthDashboardScreenState extends State<HiveHealthDashboardScreen> {
  static const int _tabIndex = 1; // Health tab

  bool get _isHealthy => widget.status.toLowerCase() == 'healthy';

  void _onNavTapped(int index) {
    if (index == _tabIndex) {
      // Return to colony health list
      Navigator.of(context).pop();
      return;
    }
    if (index == 0) {
      // Pop back to home
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    final labels = ['Home', 'Health', 'Relocate', 'Acoustic', 'Environment'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${labels[index]} module will be available in the next update.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.bgSecondary,
          ),
        ),
        backgroundColor: AppColors.panelBlack,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.hiveName} Settings',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sensors_rounded, color: AppColors.darkGreen),
                title: Text('ESP32 Telemetry Rate',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('Current: Every 2 minutes',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                onTap: () => Navigator.of(ctx).pop(),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined, color: AppColors.accent2),
                title: Text('Health Alert Thresholds',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('Temp: 30–36°C • Humidity: 55–80%',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                onTap: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScannerScreen(inferenceService: widget.inferenceService),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.bgSecondary),
                label: Text(
                  'Launch AI Frame Camera Scanner',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.bgSecondary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailedTrends() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IT23136274SensorTrendsScreen(
          hiveId: widget.hiveId,
          hiveName: widget.hiveName,
          apiaryName: widget.apiaryName,
          inferenceService: widget.inferenceService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.hiveName,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              widget.apiaryName,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary, size: 22),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // 1. Overall Colony Health Card
              _buildOverallHealthCard()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.05, end: 0),
              const SizedBox(height: 22),
              // 2. Live Sensor Data Section Title
              _buildLiveSensorHeader()
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 14),
              // 3. 2x2 Grid of Live Sensor Metrics
              _buildSensorGrid()
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 400.ms)
                  .slideY(begin: 0.06, end: 0),
              const SizedBox(height: 18),
              // 4. View Detailed Trends Action Button
              _buildViewTrendsButton()
                  .animate()
                  .fadeIn(delay: 250.ms, duration: 400.ms)
                  .slideY(begin: 0.08, end: 0),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Overall Colony Health Card ────────────────────────────────────
  Widget _buildOverallHealthCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F4EC), // Pale mint green tint
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4E8DA), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGreen.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Colony Health',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Green Pill Badge
              Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
                decoration: BoxDecoration(
                  color: _isHealthy ? const Color(0xFF2C9E4B) : AppColors.warning,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: (_isHealthy ? const Color(0xFF2C9E4B) : AppColors.warning)
                          .withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Circular check / arrow icon inside pill
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_downward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.status,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Leaf Badge inside circular disc
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.spa_rounded,
                    color: Color(0xFF38B25D),
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _isHealthy
                ? 'Conditions are within normal range.'
                : 'Attention needed: monitor humidity and temperature.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Live Sensor Header ────────────────────────────────────────────
  Widget _buildLiveSensorHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Sensor Data',
              style: GoogleFonts.inter(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Last updated: 2 min ago',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        // ESP32 Online status pill
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF2C9E4B),
                shape: BoxShape.circle,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.8, end: 1.25, duration: 1200.ms),
            const SizedBox(width: 6),
            Text(
              'ESP32 Online',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3A4A3E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 2x2 Sensor Metric Cards ───────────────────────────────────────
  Widget _buildSensorGrid() {
    return Column(
      children: [
        Row(
          children: [
            // Card 1: Temperature
            Expanded(
              child: _MetricCard(
                iconWidget: const Icon(
                  Icons.thermostat_rounded,
                  color: Color(0xFFE54B38), // Red
                  size: 26,
                ),
                title: 'Temperature',
                value: '31.2 °C',
                pillText: 'Normal',
                pillColor: const Color(0xFF2C9E4B),
                pillBg: const Color(0xFFEAF5EC),
              ),
            ),
            const SizedBox(width: 12),
            // Card 2: Humidity
            Expanded(
              child: _MetricCard(
                iconWidget: const Icon(
                  Icons.water_drop_rounded,
                  color: Color(0xFF2885F6), // Blue
                  size: 26,
                ),
                title: 'Humidity',
                value: '75 %',
                pillText: 'Normal',
                pillColor: const Color(0xFF2C9E4B),
                pillBg: const Color(0xFFEAF5EC),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Card 3: Hive Weight
            Expanded(
              child: _MetricCard(
                iconWidget: const _HoneyJarIcon(),
                title: 'Hive Weight',
                value: '12.4 kg',
                trendText: '+0.3 kg today',
                trendColor: const Color(0xFF2C9E4B),
              ),
            ),
            const SizedBox(width: 12),
            // Card 4: Bee Activity
            Expanded(
              child: _MetricCard(
                iconWidget: const SizedBox(
                  width: 28,
                  height: 24,
                  child: BeeIllustration(size: 28, animate: false),
                ),
                title: 'Bee Activity',
                value: 'Moderate',
                subText: '18 movements/min',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── View Detailed Trends Button ───────────────────────────────────
  Widget _buildViewTrendsButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGreen.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showDetailedTrends,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              children: [
                const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'View Detailed Trends',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom Navigation Bar ─────────────────────────────────────────
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.bgPrimary,
      selectedItemColor: AppColors.hiveLow,
      unselectedItemColor: AppColors.textSecondary,
      showUnselectedLabels: true,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      currentIndex: _tabIndex,
      onTap: _onNavTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.monitor_heart_outlined),
          label: 'Health',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.location_on_outlined),
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
    );
  }
}

// ── Metric Card Widget ──────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final Widget iconWidget;
  final String title;
  final String value;
  final String? pillText;
  final Color? pillColor;
  final Color? pillBg;
  final String? trendText;
  final Color? trendColor;
  final String? subText;

  const _MetricCard({
    required this.iconWidget,
    required this.title,
    required this.value,
    this.pillText,
    this.pillColor,
    this.pillBg,
    this.trendText,
    this.trendColor,
    this.subText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.9),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + Title Row
          Row(
            children: [
              iconWidget,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Value
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          // Pill or Trend footer
          if (pillText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: pillBg ?? const Color(0xFFEAF5EC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pillText!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: pillColor ?? const Color(0xFF2C9E4B),
                ),
              ),
            ),
          ] else if (trendText != null) ...[
            Row(
              children: [
                Icon(
                  Icons.north_east_rounded,
                  size: 13,
                  color: trendColor ?? const Color(0xFF2C9E4B),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    trendText!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: trendColor ?? const Color(0xFF2C9E4B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ] else if (subText != null) ...[
            Text(
              subText!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Cute Honey Jar Icon Widget ──────────────────────────────────────
class _HoneyJarIcon extends StatelessWidget {
  const _HoneyJarIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFFFFB82E), // Honey amber
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB82E).withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'H',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF9E6500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Trends Bottom Sheet ─────────────────────────────────────────────
class _TrendsBottomSheet extends StatelessWidget {
  final String hiveName;
  final InferenceService? inferenceService;

  const _TrendsBottomSheet({
    required this.hiveName,
    this.inferenceService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '24-Hour Sensor Trends',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5EC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Live Synced',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C9E4B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Trend summary rows
            _buildTrendRow(
              icon: Icons.thermostat_rounded,
              iconColor: const Color(0xFFE54B38),
              title: 'Temperature Stability',
              value: '31.2 °C (Avg: 31.8 °C)',
              status: 'Optimal Brood Range',
            ),
            const SizedBox(height: 10),
            _buildTrendRow(
              icon: Icons.water_drop_rounded,
              iconColor: const Color(0xFF2885F6),
              title: 'Internal Humidity',
              value: '75 % (Fluctuation: ±3%)',
              status: 'Healthy Ventilation',
            ),
            const SizedBox(height: 10),
            _buildTrendRow(
              icon: Icons.scale_rounded,
              iconColor: const Color(0xFFFFB82E),
              title: 'Honey & Colony Weight',
              value: '12.4 kg (+0.3 kg net gain)',
              status: 'Active Foraging Day',
            ),
            const SizedBox(height: 10),
            _buildTrendRow(
              icon: Icons.graphic_eq_rounded,
              iconColor: AppColors.accent3,
              title: 'Acoustic Sound Frequency',
              value: '240 Hz Queen Piping Pitch',
              status: 'No Swarm Signs',
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ScannerScreen(inferenceService: inferenceService),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt_outlined, size: 18, color: Colors.white),
              label: Text(
                'Perform Visual Frame AI Scan',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
