import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/sensor_reading_model.dart';
import '../services/inference_service.dart';
import '../services/sensor_reading_service.dart';
import '../utils/theme.dart';
import '../widgets/bee_illustration.dart';
import 'it23136274_ai_health_assessment_screen.dart';
import 'it23136274_alerts_history_screen.dart';
import 'it23136274_sensor_trends_screen.dart';
import 'scanner_screen.dart';
import 'relocation_assessment_screen_IT23185302.dart';
import 'IT23183186_environment_dashboard_screen.dart';

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

  static const Duration _refreshInterval = Duration(seconds: 30);

  SensorReading? _reading;
  bool _sensorLoading = true;
  String? _sensorError;
  Timer? _refreshTimer;

  /// App hive IDs are not yet linked to ESP32 device IDs, so fall back to
  /// the default device unless the hive ID is already a device ID.
  String get _sensorHiveId => widget.hiveId.startsWith('HIVE_')
      ? widget.hiveId
      : SensorReadingService.defaultHiveId;

  @override
  void initState() {
    super.initState();
    _loadLatestReading();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _loadLatestReading());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLatestReading() async {
    try {
      final reading = await SensorReadingService.instance.fetchLatestReading(_sensorHiveId);
      if (!mounted) return;
      setState(() {
        _reading = reading;
        _sensorError = null;
        _sensorLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sensorError = e.toString();
        _sensorLoading = false;
      });
    }
  }

  String get _lastUpdatedText {
    if (_sensorLoading && _reading == null) return 'Loading sensor data...';
    if (_sensorError != null && _reading == null) return 'Unable to load sensor data';
    final timestamp = _reading?.timestamp;
    if (timestamp == null) return 'No sensor data yet';
    final now = DateTime.now();
    final isToday = timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
    final formatted = isToday
        ? DateFormat.jm().format(timestamp)
        : DateFormat('MMM d, h:mm a').format(timestamp);
    return 'Last updated: $formatted';
  }

  String _formatValue(double? value, String pattern, String unit) =>
      value == null ? '-- $unit' : '${NumberFormat(pattern).format(value)} $unit';

  /// Status pill based on the alert thresholds shown in hive settings.
  ({String text, Color color, Color bg}) _rangePill(double? value, double min, double max) {
    if (value == null) {
      return (text: 'No data', color: AppColors.textSecondary, bg: AppColors.bgElevated);
    }
    if (value < min) return (text: 'Low', color: AppColors.warning, bg: AppColors.bgElevated);
    if (value > max) return (text: 'High', color: AppColors.warning, bg: AppColors.bgElevated);
    return (text: 'Normal', color: AppColors.success, bg: AppColors.lightGreenCard);
  }

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

    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const RelocationAssessmentScreenIT23185302(),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScannerScreen(
            inferenceService: widget.inferenceService,
          ),
        ),
      );
      return;
    }

    if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EnvironmentDashboardScreen(
            inferenceService: widget.inferenceService,
          ),
        ),
      );
      return;
    }
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
                leading: const Icon(Icons.sensors_rounded, color: AppColors.accent3),
                title: Text('ESP32 Telemetry Rate',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                subtitle: Text('Current: Every 2 minutes',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                onTap: () => Navigator.of(ctx).pop(),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined, color: AppColors.accent2),
                title: Text('Health Alert Thresholds',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
                icon: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.textPrimary),
                label: Text(
                  'Launch AI Frame Camera Scanner',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
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

  void _showAiHealthAssessment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IT23136274AiHealthAssessmentScreen(
          hiveId: widget.hiveId,
          hiveName: widget.hiveName,
          apiaryName: widget.apiaryName,
          initialStatus: widget.status == 'Healthy' ? 'Healthy Colony' : 'Early Stress',
          confidence: widget.status == 'Healthy' ? 0.94 : 0.87,
          inferenceService: widget.inferenceService,
        ),
      ),
    );
  }

  void _openAlertsHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IT23136274AlertsHistoryScreen(
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
                fontWeight: FontWeight.w700,
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
            icon: Badge(
              smallSize: 8,
              backgroundColor: AppColors.error,
              child: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 22),
            ),
            tooltip: 'Alerts & History',
            onPressed: _openAlertsHistory,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary, size: 22),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.darkGreen,
          onRefresh: _loadLatestReading,
          child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
              // 4. AI Health Assessment Action Button
              _buildAiAssessmentButton()
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .slideY(begin: 0.08, end: 0),
              const SizedBox(height: 12),
              // 5. View Detailed Trends Action Button
              _buildViewTrendsButton()
                  .animate()
                  .fadeIn(delay: 250.ms, duration: 400.ms)
                  .slideY(begin: 0.08, end: 0),
              const SizedBox(height: 24),
            ],
          ),
        ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Overall Colony Health Card ────────────────────────────────────
  Widget _buildOverallHealthCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showAiHealthAssessment,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.lightGreenCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overall Colony Health',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'AI Assessment',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent2,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.accent2,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Health Status Pill Badge
                  Container(
                    padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
                    decoration: BoxDecoration(
                      color: _isHealthy ? AppColors.success : AppColors.warning,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: (_isHealthy ? AppColors.success : AppColors.warning)
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
                            color: AppColors.bgSecondary.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            color: AppColors.bgSecondary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.status,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.bgSecondary,
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
                      color: AppColors.bgSecondary.withValues(alpha: 0.9),
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
                        color: AppColors.success,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _isHealthy
                    ? 'Conditions are within normal range. Tap to view AI assessment.'
                    : 'Attention needed: tap to view detected indicators & advice.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _lastUpdatedText,
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
                color: AppColors.success,
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
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 2x2 Sensor Metric Cards ───────────────────────────────────────
  Widget _buildSensorGrid() {
    final tempPill = _rangePill(_reading?.temperature, 30, 36);
    final humidityPill = _rangePill(_reading?.humidity, 55, 80);

    return Column(
      children: [
        Row(
          children: [
            // Card 1: Temperature
            Expanded(
              child: _MetricCard(
                iconWidget: const Icon(
                  Icons.thermostat_rounded,
                  color: AppColors.accent2,
                  size: 26,
                ),
                title: 'Temperature',
                value: _formatValue(_reading?.temperature, '0.#', '°C'),
                pillText: tempPill.text,
                pillColor: tempPill.color,
                pillBg: tempPill.bg,
              ),
            ),
            const SizedBox(width: 12),
            // Card 2: Humidity
            Expanded(
              child: _MetricCard(
                iconWidget: const Icon(
                  Icons.water_drop_rounded,
                  color: AppColors.blue,
                  size: 26,
                ),
                title: 'Humidity',
                value: _formatValue(_reading?.humidity, '0.#', '%'),
                pillText: humidityPill.text,
                pillColor: humidityPill.color,
                pillBg: humidityPill.bg,
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
                value: _formatValue(_reading?.weight, '0.###', 'kg'),
                subText: 'Load cell reading',
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

  // ── AI Health Assessment Button ────────────────────────────────────
  Widget _buildAiAssessmentButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showAiHealthAssessment,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              children: [
                const Icon(
                  Icons.health_and_safety_outlined,
                  color: AppColors.accent2,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Health Assessment',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Colony status, indicators & recommendations',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── View Detailed Trends Button ───────────────────────────────────
  Widget _buildViewTrendsButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
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
                  color: AppColors.textPrimary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'View Detailed Trends',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textPrimary,
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
                color: pillBg ?? AppColors.lightGreenCard,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pillText!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: pillColor ?? AppColors.success,
                ),
              ),
            ),
          ] else if (trendText != null) ...[
            Row(
              children: [
                Icon(
                  Icons.north_east_rounded,
                  size: 13,
                  color: trendColor ?? AppColors.success,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    trendText!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: trendColor ?? AppColors.success,
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
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
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
            color: AppColors.bgSecondary.withValues(alpha: 0.85),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'H',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: AppColors.hiveDoor,
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
                    color: AppColors.lightGreenCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Live Synced',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Trend summary rows
            _buildTrendRow(
              icon: Icons.thermostat_rounded,
              iconColor: AppColors.error,
              title: 'Temperature Stability',
              value: '31.2 °C (Avg: 31.8 °C)',
              status: 'Optimal Brood Range',
            ),
            const SizedBox(height: 10),
            _buildTrendRow(
              icon: Icons.water_drop_rounded,
              iconColor: AppColors.blue,
              title: 'Internal Humidity',
              value: '75 % (Fluctuation: ±3%)',
              status: 'Healthy Ventilation',
            ),
            const SizedBox(height: 10),
            _buildTrendRow(
              icon: Icons.scale_rounded,
              iconColor: AppColors.accent,
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
              icon: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.textPrimary),
              label: Text(
                'Perform Visual Frame AI Scan',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
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
