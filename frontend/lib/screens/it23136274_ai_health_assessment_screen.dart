import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sensor_reading_model.dart';
import '../services/inference_service.dart';
import '../services/it23136274_colony_health_service.dart';
import '../services/sensor_reading_service.dart';
import '../utils/sensor_analytics.dart';
import '../utils/theme.dart';
import '../widgets/it23136274_sensor_anomaly_card.dart';
import 'it23136274_alerts_history_screen.dart';
import 'it23136274_sensor_trends_screen.dart';
import 'IT23185302_relocation_assessment_screen.dart';
import 'IT23183186_environment_dashboard_screen.dart';
import 'scanner_screen.dart';

/// Student Registration: IT23136274
/// Research Component: AI-Based Colony Health Monitoring
/// Feature: AI Health Assessment (Colony Status) Screen
///
/// Fully conforms to Skills/Frontend_skill.md:
/// - Palette: Strictly uses AppColors (bgPrimary, bgSecondary, bgElevated, border,
///   textPrimary, textSecondary, accent, accent2, accent3, success, warning, error,
///   info, badgeLeafBg, badgeLeafFg, badgeTempBg, badgeTempFg, hiveLow, hiveDoor).
/// - Typography: GoogleFonts.inter across all elements with canonical weights & sizes.
/// - Architecture: Scaffold, AppBar, SafeArea, SingleChildScrollView (padding 20).
/// - Shared 5-item fixed bottom navigation with AppColors.hiveLow on Health index.
/// - Zero raw Color(0x...) or Colors.* calls.
class IT23136274AiHealthAssessmentScreen extends StatefulWidget {
  final String hiveId;
  final String hiveName;
  final String apiaryName;
  final List<String>? indicators;
  final InferenceService? inferenceService;

  const IT23136274AiHealthAssessmentScreen({
    super.key,
    this.hiveId = 'hive-01',
    this.hiveName = 'Hive 01',
    this.apiaryName = 'Yakkala Apiary',
    this.indicators,
    this.inferenceService,
  });

  @override
  State<IT23136274AiHealthAssessmentScreen> createState() =>
      _IT23136274AiHealthAssessmentScreenState();
}

typedef AiHealthAssessmentScreen = IT23136274AiHealthAssessmentScreen;

class _IT23136274AiHealthAssessmentScreenState
    extends State<IT23136274AiHealthAssessmentScreen> {
  static const int _tabIndex = 1; // Health tab

  /// Readings used for the weight trend (never a single reading).
  static const Duration _weightTrendWindow = Duration(hours: 24);

  late final SensorAnomalyController _anomaly;

  SensorReading? _latest;
  List<SensorReading> _recentReadings = const [];
  bool _latestLoading = true;
  bool _recentLoading = true;
  String? _sensorError;
  StreamSubscription<SensorReading?>? _latestSub;
  StreamSubscription<List<SensorReading>>? _recentSub;

  @override
  void initState() {
    super.initState();
    _anomaly = SensorAnomalyController(SensorReadingService.resolveSensorHiveId(widget.hiveId));
    _listenToSensorData();
  }

  @override
  void dispose() {
    _latestSub?.cancel();
    _recentSub?.cancel();
    _anomaly.dispose();
    super.dispose();
  }

  void _listenToSensorData() {
    final service = SensorReadingService.instance;
    final sensorHiveId = SensorReadingService.resolveSensorHiveId(widget.hiveId);

    _latestSub = service.streamLatestReading(sensorHiveId).listen(
      (reading) {
        if (!mounted) return;
        setState(() {
          _latest = reading;
          _latestLoading = false;
          _sensorError = null;
        });
        // Re-runs the anomaly model only when a new reading arrives.
        _anomaly.onReading(reading);
      },
      onError: _onSensorError,
    );

    _recentSub = service
        .streamReadingsForRange(sensorHiveId, DateTime.now().subtract(_weightTrendWindow))
        .listen(
      (readings) {
        if (!mounted) return;
        setState(() {
          _recentReadings = readings;
          _recentLoading = false;
        });
      },
      onError: _onSensorError,
    );
  }

  void _onSensorError(Object error) {
    if (!mounted) return;
    setState(() {
      _sensorError = error.toString();
      _latestLoading = false;
      _recentLoading = false;
    });
  }

  SensorDisplayStatus get _temperatureStatus =>
      SensorDisplayRules.temperatureStatus(_latest?.temperature);

  SensorDisplayStatus get _humidityStatus => SensorDisplayRules.humidityStatus(_latest?.humidity);

  WeightTrend get _weightTrend {
    final cutoff = DateTime.now().subtract(_weightTrendWindow);
    return calculateWeightTrend(
      _recentReadings.where((r) => r.timestamp!.isAfter(cutoff)).toList(),
    );
  }

  /// Indicators passed in by the caller win; otherwise they are derived from
  /// live sensor data with the display-only rules (not the anomaly model).
  List<String> get _indicators =>
      widget.indicators ??
      SensorDisplayRules.indicators(
        temperature: _temperatureStatus,
        humidity: _humidityStatus,
        weightTrend: _weightTrend,
      );

  String get _lastUpdatedText {
    if (_latestLoading && _latest == null) return 'Loading sensor data...';
    if (_sensorError != null && _latest == null) return 'Unable to load sensor data';
    final timestamp = _latest?.timestamp;
    if (timestamp == null) return 'No sensor data available';
    return 'Last updated: ${formatReadingTime(timestamp)}';
  }

  void _onNavTapped(int index) {
    if (index == _tabIndex) {
      Navigator.of(context).pop();
      return;
    }
    if (index == 0) {
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

  void _openSensorTrends() {
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

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Detected Indicators',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'These indicators compare the latest ESP32 readings with simple display ranges '
          '(Temperature ${SensorDisplayRules.tempMin.toInt()}–${SensorDisplayRules.tempMax.toInt()} °C, '
          'Humidity ${SensorDisplayRules.humidityMin.toInt()}–${SensorDisplayRules.humidityMax.toInt()} %) '
          'and the 24-hour weight trend. They are separate from the experimental anomaly model '
          'and do not diagnose colony health.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Understood',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'AI Health Assessment',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.hiveName} • ${widget.apiaryName}',
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
            icon: const Icon(Icons.history_rounded, color: AppColors.textPrimary, size: 22),
            tooltip: 'Alerts & History',
            onPressed: () {
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
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 14),

              // 1. Sensor Anomaly Status Card (experimental Isolation Forest V2)
              _buildSensorAnomalyCard(),
              const SizedBox(height: 18),

              // 2. Detected Indicators Card
              _buildDetectedIndicatorsCard(),
              const SizedBox(height: 16),

              // 3. Recommendation Card
              _buildRecommendationCard(),
              const SizedBox(height: 18),

              // 4. Sensor Summary Card
              _buildSensorSummaryCard(),
              const SizedBox(height: 18),

              // 5. Action Button: View Detailed Trends
              _buildTrendsButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── 1. Sensor Anomaly Status Card ─────────────────────────────────────
  Widget _buildSensorAnomalyCard() {
    return ListenableBuilder(
      listenable: _anomaly,
      builder: (context, _) => IT23136274SensorAnomalyCard(
        controller: _anomaly,
        title: 'Sensor Anomaly Status',
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }

  // ── 2. Detected Indicators Card ───────────────────────────────────────
  Widget _buildDetectedIndicatorsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Detected Indicators',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _showInfoDialog,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_indicators.isEmpty)
          Text(
            _latest == null
                ? 'Waiting for sensor data.'
                : 'No readings outside the display ranges.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ..._indicators.map((indicator) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: 4, right: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.accent2,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    indicator,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  // ── 3. Recommendation Card ───────────────────────────────────────────
  Widget _buildRecommendationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.badgeTempBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.18),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: AppColors.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommendation',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                ListenableBuilder(
                  listenable: _anomaly,
                  builder: (context, _) => Text(
                    _anomaly.result?.recommendation ??
                        'Available once the sensor anomaly check has run on the latest reading.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accent2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms, delay: 150.ms);
  }

  // ── 4. Sensor Summary Card ───────────────────────────────────────────
  Widget _buildSensorSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sensor Summary',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_latestLoading && _latest == null) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
              ],
            ],
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
          const SizedBox(height: 14),

          // Row 1: Temperature
          _buildSensorSummaryRow(
            icon: Icons.thermostat_rounded,
            iconColor: AppColors.accent2,
            name: 'Temperature',
            value: formatSensorValue(_latest?.temperature, '°C'),
            badgeText: _temperatureStatus.label,
            isWarning: _temperatureStatus.isWarning,
            isNeutral: _temperatureStatus == SensorDisplayStatus.unknown,
          ),
          const Divider(color: AppColors.border, height: 20, thickness: 0.6),

          // Row 2: Humidity
          _buildSensorSummaryRow(
            icon: Icons.water_drop_rounded,
            iconColor: AppColors.info,
            name: 'Humidity',
            value: formatSensorValue(_latest?.humidity, '%'),
            badgeText: _humidityStatus.label,
            isWarning: _humidityStatus.isWarning,
            isNeutral: _humidityStatus == SensorDisplayStatus.unknown,
          ),
          const Divider(color: AppColors.border, height: 20, thickness: 0.6),

          // Row 3: Hive Weight (badge = trend over recent readings)
          _buildSensorSummaryRow(
            icon: Icons.scale_rounded,
            iconColor: AppColors.accent,
            name: 'Hive Weight',
            value: formatSensorValue(_latest?.weight, 'kg', pattern: '0.###'),
            badgeText: _recentLoading ? '...' : _weightTrend.label,
            isWarning: _weightTrend == WeightTrend.decreasing,
            isNeutral: _recentLoading || _weightTrend == WeightTrend.insufficientData,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
  }

  Widget _buildSensorSummaryRow({
    required IconData icon,
    required Color iconColor,
    required String name,
    required String value,
    required String badgeText,
    required bool isWarning,
    bool isNeutral = false,
  }) {
    final badgeBg = isNeutral
        ? AppColors.bgElevated
        : (isWarning ? AppColors.badgeTempBg : AppColors.badgeLeafBg);
    final badgeFg = isNeutral
        ? AppColors.textSecondary
        : (isWarning ? AppColors.error : AppColors.success);

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: badgeFg.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Text(
            badgeText,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: badgeFg,
            ),
          ),
        ),
      ],
    );
  }

  // ── 5. Action Button: View Detailed Trends ────────────────────────────
  Widget _buildTrendsButton() {
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
          onTap: _openSensorTrends,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.show_chart_rounded,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'View Detailed Sensor Trends',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 550.ms, delay: 250.ms);
  }

  // ── Bottom Navigation Bar (Conforms to Frontend_skill.md) ─────────────
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
