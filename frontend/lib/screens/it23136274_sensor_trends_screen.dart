import 'dart:async';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/sensor_reading_model.dart';
import '../services/inference_service.dart';
import '../services/sensor_reading_service.dart';
import '../utils/sensor_analytics.dart';
import '../utils/theme.dart';
import 'IT23185302_relocation_assessment_screen.dart';
import 'IT23183186_environment_dashboard_screen.dart';
import 'scanner_screen.dart';

/// Student Registration: IT23136274
/// Research Component: AI-Based Colony Health Monitoring
/// Feature: Sensor Trends (Graph View) Screen
///
/// Fully conforms to Skills/Frontend_skill.md:
/// - Palette: Strictly uses AppColors (bgPrimary, bgSecondary, bgElevated, border,
///   textPrimary, textSecondary, accent, hiveLow, hiveDoor).
/// - Typography: GoogleFonts.inter across all elements with standard weights.
/// - Architecture: Scaffold, AppBar, SafeArea, SingleChildScrollView (padding 20).
/// - Shared 5-item fixed bottom navigation with AppColors.hiveLow.
/// - Zero raw Color(0x...) or Colors.* calls.
class IT23136274SensorTrendsScreen extends StatefulWidget {
  final String hiveId;
  final String hiveName;
  final String apiaryName;
  final String initialSensor;
  final InferenceService? inferenceService;

  const IT23136274SensorTrendsScreen({
    super.key,
    this.hiveId = 'hive-01',
    this.hiveName = 'Hive Box #01',
    this.apiaryName = 'Siyane Bigu',
    this.initialSensor = 'Temperature',
    this.inferenceService,
  });

  @override
  State<IT23136274SensorTrendsScreen> createState() =>
      _IT23136274SensorTrendsScreenState();
}

typedef SensorTrendsScreen = IT23136274SensorTrendsScreen;

enum SensorType { temperature, humidity, weight }

enum TimeRange { h24, d7, d30 }

class _IT23136274SensorTrendsScreenState
    extends State<IT23136274SensorTrendsScreen> {
  static const int _tabIndex = 1; // Health tab

  late SensorType _selectedSensor;
  TimeRange _selectedTimeRange = TimeRange.h24;

  // Live readings for the selected time range (all sensor tabs share them).
  List<SensorReading> _readings = const [];
  bool _loading = true;
  String? _error;
  StreamSubscription<List<SensorReading>>? _readingsSub;

  @override
  void initState() {
    super.initState();
    _selectedSensor = _parseSensor(widget.initialSensor);
    _listenToRange();
  }

  @override
  void dispose() {
    _readingsSub?.cancel();
    super.dispose();
  }

  /// (Re)subscribes to live Firestore readings for the selected time range.
  void _listenToRange() {
    _readingsSub?.cancel();
    _readings = const [];
    _loading = true;
    _error = null;

    final start = DateTime.now().subtract(_rangeDuration(_selectedTimeRange));
    _readingsSub = SensorReadingService.instance
        .streamReadingsForRange(SensorReadingService.resolveSensorHiveId(widget.hiveId), start)
        .listen(
      (readings) {
        if (!mounted) return;
        setState(() {
          _readings = readings;
          _loading = false;
          _error = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      },
    );
  }

  SensorType _parseSensor(String sensor) {
    switch (sensor.toLowerCase()) {
      case 'humidity':
        return SensorType.humidity;
      case 'weight':
        return SensorType.weight;
      case 'temperature':
      default:
        return SensorType.temperature;
    }
  }

  String get _sensorTitle {
    switch (_selectedSensor) {
      case SensorType.temperature:
        return 'Temperature';
      case SensorType.humidity:
        return 'Humidity';
      case SensorType.weight:
        return 'Weight';
    }
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

  // ── Data & Metrics Providers ──────────────────────────────────────────

  _SensorTrendData _getTrendData() {
    switch (_selectedSensor) {
      case SensorType.temperature:
        return _buildLiveTrendData(
          name: 'Temperature',
          unit: '°C',
          valueOf: (r) => r.temperature,
        );
      case SensorType.humidity:
        return _buildLiveTrendData(
          name: 'Humidity',
          unit: '%',
          valueOf: (r) => r.humidity,
        );
      case SensorType.weight:
        return _buildLiveTrendData(
          name: 'Weight',
          unit: 'kg',
          valueOf: (r) => r.weight,
          pattern: '0.###',
          valueDecimals: 3,
          minAxisSpan: 0.1,
        );
    }
  }

  // ── Live Firestore Trend Data (Temperature, Humidity, Weight) ─────────

  Duration _rangeDuration(TimeRange range) {
    switch (range) {
      case TimeRange.h24:
        return const Duration(hours: 24);
      case TimeRange.d7:
        return const Duration(days: 7);
      case TimeRange.d30:
        return const Duration(days: 30);
    }
  }

  String _rangeLabel(TimeRange range) {
    switch (range) {
      case TimeRange.h24:
        return '24 hours';
      case TimeRange.d7:
        return '7 days';
      case TimeRange.d30:
        return '30 days';
    }
  }

  /// Chart points are bucket averages so dense ESP32 data stays readable.
  Duration _bucketSize(TimeRange range) {
    switch (range) {
      case TimeRange.h24:
        return const Duration(hours: 1);
      case TimeRange.d7:
        return const Duration(hours: 6);
      case TimeRange.d30:
        return const Duration(days: 1);
    }
  }

  _SensorTrendData _buildLiveTrendData({
    required String name,
    required String unit,
    required double? Function(SensorReading reading) valueOf,
    String pattern = '0.#',
    int valueDecimals = 1,
    double minAxisSpan = 1,
  }) {
    final range = _selectedTimeRange;
    final start = DateTime.now().subtract(_rangeDuration(range));
    final inRange = _readings.where((r) => r.timestamp!.isAfter(start)).toList();
    final points = inRange
        .where((r) => valueOf(r) != null)
        .map((r) => (t: r.timestamp!, v: valueOf(r)!))
        .toList();
    final values = points.map((p) => p.v).toList();
    String fmt(double? v) => formatSensorValue(v, unit, pattern: pattern);

    // X axis: hours since range start (24H) or days since range start (7D/30D).
    final xUnitMinutes = range == TimeRange.h24 ? 60.0 : 1440.0;
    final maxX = _rangeDuration(range).inMinutes / xUnitMinutes;
    double xOf(DateTime t) => t.difference(start).inSeconds / 60.0 / xUnitMinutes;

    final buckets = <int, List<({double x, double v})>>{};
    final bucketMs = _bucketSize(range).inMilliseconds;
    for (final p in points) {
      final key = p.t.difference(start).inMilliseconds ~/ bucketMs;
      buckets.putIfAbsent(key, () => []).add((x: xOf(p.t), v: p.v));
    }
    final spots = (buckets.keys.toList()..sort()).map((key) {
      final bucket = buckets[key]!;
      final x = bucket.map((b) => b.x).reduce((a, b) => a + b) / bucket.length;
      final v = bucket.map((b) => b.v).reduce((a, b) => a + b) / bucket.length;
      return FlSpot(x.clamp(0, maxX).toDouble(), v);
    }).toList();

    final axis = _niceYAxis(
      spots.isEmpty ? null : spots.map((s) => s.y).reduce(math.min),
      spots.isEmpty ? null : spots.map((s) => s.y).reduce(math.max),
      minAxisSpan,
    );

    final bottomInterval = range == TimeRange.h24 ? 6.0 : (range == TimeRange.d7 ? 1.0 : 7.0);
    final labelFormat = range == TimeRange.h24
        ? DateFormat('ha')
        : (range == TimeRange.d7 ? DateFormat('E') : DateFormat('MMM d'));
    final bottomTitles = <int, String>{
      for (var x = 0.0; x <= maxX; x += bottomInterval)
        x.toInt(): labelFormat.format(
            start.add(Duration(minutes: (x * xUnitMinutes).round()))),
    };

    String insight;
    if (values.isEmpty) {
      insight = 'No sensor data available for the last ${_rangeLabel(range)}.';
    } else {
      insight = '$name averaged ${fmt(SensorStats.average(values))} over the last '
          '${_rangeLabel(range)} (${values.length} readings), ranging from '
          '${fmt(SensorStats.min(values))} to ${fmt(SensorStats.max(values))}.';
      if (_selectedSensor == SensorType.temperature) {
        insight += ' Latest reading: ${SensorDisplayRules.temperatureStatus(values.last).label} '
            '(display range ${SensorDisplayRules.tempMin.toInt()}–${SensorDisplayRules.tempMax.toInt()} °C).';
      } else if (_selectedSensor == SensorType.humidity) {
        insight += ' Latest reading: ${SensorDisplayRules.humidityStatus(values.last).label} '
            '(display range ${SensorDisplayRules.humidityMin.toInt()}–${SensorDisplayRules.humidityMax.toInt()} %).';
      } else if (_selectedSensor == SensorType.weight) {
        insight += ' Weight trend: ${calculateWeightTrend(inRange).label}.';
      }
    }

    String? emptyMessage;
    if (spots.isEmpty) {
      emptyMessage = _error != null ? 'Unable to load sensor data' : 'No sensor data available';
    }

    return _SensorTrendData(
      unit: unit,
      current: fmt(values.isEmpty ? null : values.last),
      average: fmt(SensorStats.average(values)),
      min: fmt(SensorStats.min(values)),
      max: fmt(SensorStats.max(values)),
      insight: insight,
      minX: 0,
      maxX: maxX,
      minY: axis.min,
      maxY: axis.max,
      leftInterval: axis.step,
      bottomInterval: bottomInterval,
      horizontalGridInterval: axis.step,
      verticalGridInterval: bottomInterval,
      spots: spots,
      bottomTitles: bottomTitles,
      leftDecimals: axis.decimals,
      valueDecimals: valueDecimals,
      loading: _loading,
      emptyMessage: _loading ? null : emptyMessage,
    );
  }

  /// Rounded Y axis bounds with ~4 grid steps around [lo]..[hi].
  ({double min, double max, double step, int decimals}) _niceYAxis(
      double? lo, double? hi, double minSpan) {
    if (lo == null || hi == null) return (min: 0, max: 4 * minSpan, step: minSpan, decimals: 0);
    final span = math.max(hi - lo, minSpan);
    final raw = span / 4;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / magnitude;
    final step = (f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10) * magnitude;
    var min = (lo / step).floor() * step;
    var max = (hi / step).ceil() * step;
    if (max - min < step * 2) {
      min -= step;
      max += step;
    }
    var decimals = 0;
    while (decimals < 4 && ((step * math.pow(10, decimals)) % 1).abs() > 1e-6) {
      decimals++;
    }
    return (min: min, max: max, step: step, decimals: decimals);
  }

  // ── Build Method ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final data = _getTrendData();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _sensorTitle,
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // 1. Sensor Category Selector Pills
              _buildSensorSelector(),
              const SizedBox(height: 16),

              // 2. Time Range Selector Pills (24H, 7D, 30D)
              _buildTimeRangeSelector(),
              const SizedBox(height: 18),

              // 3. Line Chart Card
              _buildChartCard(data),
              const SizedBox(height: 18),

              // 4. Statistics Card (Current, Average, Min, Max)
              _buildStatsCard(data),
              const SizedBox(height: 16),

              // 5. AI Insights Card
              _buildInsightsCard(data),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Sensor Category Pills ─────────────────────────────────────────────
  Widget _buildSensorSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildSensorPill(SensorType.temperature, 'Temperature'),
          const SizedBox(width: 8),
          _buildSensorPill(SensorType.humidity, 'Humidity'),
          const SizedBox(width: 8),
          _buildSensorPill(SensorType.weight, 'Weight'),
        ],
      ),
    );
  }

  Widget _buildSensorPill(SensorType type, String label) {
    final isSelected = _selectedSensor == type;

    return InkWell(
      onTap: () {
        if (!isSelected) {
          setState(() => _selectedSensor = type);
        }
      },
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Time Range Selector Pills ─────────────────────────────────────────
  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTimeRangePill(TimeRange.h24, '24H')),
          const SizedBox(width: 6),
          Expanded(child: _buildTimeRangePill(TimeRange.d7, '7D')),
          const SizedBox(width: 6),
          Expanded(child: _buildTimeRangePill(TimeRange.d30, '30D')),
        ],
      ),
    );
  }

  Widget _buildTimeRangePill(TimeRange range, String label) {
    final isSelected = _selectedTimeRange == range;

    return InkWell(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _selectedTimeRange = range;
            _listenToRange();
          });
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.32),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Line Chart Card ───────────────────────────────────────────────────
  Widget _buildChartCard(_SensorTrendData data) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 20, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                Positioned.fill(child: _buildLineChart(data)),
                if (data.loading)
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accent),
                    ),
                  )
                else if (data.emptyMessage != null)
                  Center(
                    child: Text(
                      data.emptyMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildLineChart(_SensorTrendData data) {
    return LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) =>
                        AppColors.panelBlack.withValues(alpha: 0.88),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(data.valueDecimals)} ${data.unit}',
                          GoogleFonts.inter(
                            color: AppColors.bgSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: true,
                  horizontalInterval: data.horizontalGridInterval,
                  verticalInterval: data.verticalGridInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.45),
                    strokeWidth: 0.8,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.45),
                    strokeWidth: 0.8,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: data.bottomInterval,
                      getTitlesWidget: (value, meta) {
                        final label = data.bottomTitles[value.toInt()] ?? '';
                        if (label.isEmpty) return const SizedBox.shrink();
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 6,
                          child: Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: data.leftInterval,
                      getTitlesWidget: (value, meta) {
                        if (value < data.minY || value > data.maxY) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4,
                          child: Text(
                            value.toStringAsFixed(data.leftDecimals),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: data.minX,
                maxX: data.maxX,
                minY: data.minY,
                maxY: data.maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: data.spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    color: AppColors.accent,
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3.2,
                        color: AppColors.accent,
                        strokeWidth: 1.5,
                        strokeColor: AppColors.bgSecondary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.accent.withValues(alpha: 0.35),
                          AppColors.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
  }

  // ── Statistics Card (2x2 Grid) ────────────────────────────────────────
  Widget _buildStatsCard(_SensorTrendData data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(label: 'Current', value: data.current),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(label: 'Average', value: data.average),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(label: 'Min', value: data.min),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(label: 'Max', value: data.max),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildStatItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── AI Insights Card ──────────────────────────────────────────────────
  Widget _buildInsightsCard(_SensorTrendData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
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
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insights',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.insight,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms, delay: 150.ms);
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

/// Helper model for sensor graph configurations and summaries
class _SensorTrendData {
  final String unit;
  final String current;
  final String average;
  final String min;
  final String max;
  final String insight;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double leftInterval;
  final double bottomInterval;
  final double horizontalGridInterval;
  final double verticalGridInterval;
  final List<FlSpot> spots;
  final Map<int, String> bottomTitles;
  final int leftDecimals;
  final int valueDecimals;
  final bool loading;
  final String? emptyMessage;

  const _SensorTrendData({
    this.leftDecimals = 0,
    this.valueDecimals = 1,
    this.loading = false,
    this.emptyMessage,
    required this.unit,
    required this.current,
    required this.average,
    required this.min,
    required this.max,
    required this.insight,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.leftInterval,
    required this.bottomInterval,
    required this.horizontalGridInterval,
    required this.verticalGridInterval,
    required this.spots,
    required this.bottomTitles,
  });
}
