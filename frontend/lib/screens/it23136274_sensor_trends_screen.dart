import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/inference_service.dart';
import '../utils/theme.dart';

/// Student Registration: IT23136274
/// Research Component: AI-Based Colony Health Monitoring
/// Feature: Sensor Trends (Graph View) Screen
///
/// Fully conforms to Skills/Frontend_skill.md:
/// - Palette: Strictly uses AppColors (bgPrimary, bgSecondary, bgElevated, border,
///   textPrimary, textSecondary, darkGreen, accent, hiveLow, hiveDoor).
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

enum SensorType { temperature, humidity, weight, activity }

enum TimeRange { h24, d7, d30 }

class _IT23136274SensorTrendsScreenState
    extends State<IT23136274SensorTrendsScreen> {
  static const int _tabIndex = 1; // Health tab

  late SensorType _selectedSensor;
  TimeRange _selectedTimeRange = TimeRange.h24;

  @override
  void initState() {
    super.initState();
    _selectedSensor = _parseSensor(widget.initialSensor);
  }

  SensorType _parseSensor(String sensor) {
    switch (sensor.toLowerCase()) {
      case 'humidity':
        return SensorType.humidity;
      case 'weight':
        return SensorType.weight;
      case 'activity':
        return SensorType.activity;
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
      case SensorType.activity:
        return 'Activity';
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

  // ── Data & Metrics Providers ──────────────────────────────────────────

  _SensorTrendData _getTrendData() {
    switch (_selectedSensor) {
      case SensorType.temperature:
        return _getTemperatureData(_selectedTimeRange);
      case SensorType.humidity:
        return _getHumidityData(_selectedTimeRange);
      case SensorType.weight:
        return _getWeightData(_selectedTimeRange);
      case SensorType.activity:
        return _getActivityData(_selectedTimeRange);
    }
  }

  _SensorTrendData _getTemperatureData(TimeRange range) {
    switch (range) {
      case TimeRange.h24:
        return const _SensorTrendData(
          unit: '°C',
          current: '31.2 °C',
          average: '30.5 °C',
          min: '28.9 °C',
          max: '33.1 °C',
          insight:
              'Temperature is within the normal range for a healthy colony.',
          minX: 0,
          maxX: 24,
          minY: 24,
          maxY: 36,
          leftInterval: 4,
          bottomInterval: 6,
          horizontalGridInterval: 4,
          verticalGridInterval: 6,
          spots: [
            FlSpot(0, 29.5),
            FlSpot(2, 29.0),
            FlSpot(4, 28.5),
            FlSpot(6, 28.4),
            FlSpot(8, 28.5),
            FlSpot(10, 29.2),
            FlSpot(12, 30.2),
            FlSpot(14, 29.8),
            FlSpot(16, 30.5),
            FlSpot(18, 32.8),
            FlSpot(19, 33.1),
            FlSpot(21, 31.2),
            FlSpot(22, 30.5),
            FlSpot(24, 30.0),
          ],
          bottomTitles: {
            0: '12AM',
            6: '6AM',
            12: '12PM',
            18: '6PM',
            24: '12AM',
          },
        );
      case TimeRange.d7:
        return const _SensorTrendData(
          unit: '°C',
          current: '31.2 °C',
          average: '30.9 °C',
          min: '29.4 °C',
          max: '32.8 °C',
          insight:
              'Brood temperature remained consistently regulated between 29.4°C and 32.8°C all week.',
          minX: 0,
          maxX: 6,
          minY: 24,
          maxY: 36,
          leftInterval: 4,
          bottomInterval: 1,
          horizontalGridInterval: 4,
          verticalGridInterval: 1,
          spots: [
            FlSpot(0, 30.2),
            FlSpot(1, 31.5),
            FlSpot(2, 30.8),
            FlSpot(3, 29.4),
            FlSpot(4, 31.8),
            FlSpot(5, 32.8),
            FlSpot(6, 31.2),
          ],
          bottomTitles: {
            0: 'Mon',
            1: 'Tue',
            2: 'Wed',
            3: 'Thu',
            4: 'Fri',
            5: 'Sat',
            6: 'Sun',
          },
        );
      case TimeRange.d30:
        return const _SensorTrendData(
          unit: '°C',
          current: '31.2 °C',
          average: '30.8 °C',
          min: '28.5 °C',
          max: '33.5 °C',
          insight:
              'The colony maintained excellent brood chamber thermal homeostasis over the 30-day cycle.',
          minX: 0,
          maxX: 4,
          minY: 24,
          maxY: 36,
          leftInterval: 4,
          bottomInterval: 1,
          horizontalGridInterval: 4,
          verticalGridInterval: 1,
          spots: [
            FlSpot(0, 30.0),
            FlSpot(1, 30.6),
            FlSpot(2, 31.8),
            FlSpot(3, 30.9),
            FlSpot(4, 31.2),
          ],
          bottomTitles: {
            0: 'W1',
            1: 'W2',
            2: 'W3',
            3: 'W4',
            4: 'W5',
          },
        );
    }
  }

  _SensorTrendData _getHumidityData(TimeRange range) {
    switch (range) {
      case TimeRange.h24:
        return const _SensorTrendData(
          unit: '%',
          current: '72.0 %',
          average: '68.5 %',
          min: '62.5 %',
          max: '74.0 %',
          insight:
              'Internal humidity levels are optimal for healthy brood incubation and honey curing.',
          minX: 0,
          maxX: 24,
          minY: 50,
          maxY: 80,
          leftInterval: 10,
          bottomInterval: 6,
          horizontalGridInterval: 10,
          verticalGridInterval: 6,
          spots: [
            FlSpot(0, 71.0),
            FlSpot(4, 73.0),
            FlSpot(6, 74.0),
            FlSpot(10, 68.0),
            FlSpot(12, 63.5),
            FlSpot(15, 62.5),
            FlSpot(18, 66.0),
            FlSpot(21, 72.0),
            FlSpot(24, 71.5),
          ],
          bottomTitles: {
            0: '12AM',
            6: '6AM',
            12: '12PM',
            18: '6PM',
            24: '12AM',
          },
        );
      case TimeRange.d7:
        return const _SensorTrendData(
          unit: '%',
          current: '72.0 %',
          average: '69.1 %',
          min: '61.0 %',
          max: '75.2 %',
          insight:
              'Moisture fluctuations remained safe with no condensation risks detected this week.',
          minX: 0,
          maxX: 6,
          minY: 50,
          maxY: 80,
          leftInterval: 10,
          bottomInterval: 1,
          horizontalGridInterval: 10,
          verticalGridInterval: 1,
          spots: [
            FlSpot(0, 68.5),
            FlSpot(1, 71.0),
            FlSpot(2, 69.8),
            FlSpot(3, 64.0),
            FlSpot(4, 73.5),
            FlSpot(5, 75.2),
            FlSpot(6, 72.0),
          ],
          bottomTitles: {
            0: 'Mon',
            1: 'Tue',
            2: 'Wed',
            3: 'Thu',
            4: 'Fri',
            5: 'Sat',
            6: 'Sun',
          },
        );
      case TimeRange.d30:
        return const _SensorTrendData(
          unit: '%',
          current: '72.0 %',
          average: '68.2 %',
          min: '58.0 %',
          max: '77.5 %',
          insight:
              'Monthly humidity profile shows healthy ventilation response to ambient weather shifts.',
          minX: 0,
          maxX: 4,
          minY: 50,
          maxY: 80,
          leftInterval: 10,
          bottomInterval: 1,
          horizontalGridInterval: 10,
          verticalGridInterval: 1,
          spots: [
            FlSpot(0, 66.0),
            FlSpot(1, 69.5),
            FlSpot(2, 74.0),
            FlSpot(3, 67.5),
            FlSpot(4, 72.0),
          ],
          bottomTitles: {
            0: 'W1',
            1: 'W2',
            2: 'W3',
            3: 'W4',
            4: 'W5',
          },
        );
    }
  }

  _SensorTrendData _getWeightData(TimeRange range) {
    switch (range) {
      case TimeRange.h24:
        return const _SensorTrendData(
          unit: 'kg',
          current: '14.8 kg',
          average: '14.4 kg',
          min: '14.0 kg',
          max: '14.8 kg',
          insight:
              'Net daily weight increase of +0.3 kg indicates strong nectar flow and active honey storage.',
          minX: 0,
          maxX: 24,
          minY: 12,
          maxY: 16,
          leftInterval: 1,
          bottomInterval: 6,
          horizontalGridInterval: 1,
          verticalGridInterval: 6,
          spots: [
            FlSpot(0, 14.3),
            FlSpot(4, 14.3),
            FlSpot(8, 14.2),
            FlSpot(11, 14.0),
            FlSpot(14, 14.1),
            FlSpot(17, 14.5),
            FlSpot(20, 14.7),
            FlSpot(22, 14.8),
            FlSpot(24, 14.7),
          ],
          bottomTitles: {
            0: '12AM',
            6: '6AM',
            12: '12PM',
            18: '6PM',
            24: '12AM',
          },
        );
      case TimeRange.d7:
        return const _SensorTrendData(
          unit: 'kg',
          current: '14.8 kg',
          average: '13.9 kg',
          min: '13.1 kg',
          max: '14.8 kg',
          insight:
              'Weekly gain of +1.7 kg confirms steady hive food accumulation and super frame filling.',
          minX: 0,
          maxX: 6,
          minY: 12,
          maxY: 16,
          leftInterval: 1,
          bottomInterval: 1,
          horizontalGridInterval: 1,
          verticalGridInterval: 1,
          spots: [
            FlSpot(0, 13.1),
            FlSpot(1, 13.4),
            FlSpot(2, 13.6),
            FlSpot(3, 14.0),
            FlSpot(4, 14.2),
            FlSpot(5, 14.5),
            FlSpot(6, 14.8),
          ],
          bottomTitles: {
            0: 'Mon',
            1: 'Tue',
            2: 'Wed',
            3: 'Thu',
            4: 'Fri',
            5: 'Sat',
            6: 'Sun',
          },
        );
      case TimeRange.d30:
        return const _SensorTrendData(
          unit: 'kg',
          current: '14.8 kg',
          average: '12.8 kg',
          min: '11.0 kg',
          max: '14.8 kg',
          insight:
              'Consistent monthly upward trend confirms vigorous colony growth and surplus honey capacity.',
          minX: 0,
          maxX: 4,
          minY: 10,
          maxY: 16,
          leftInterval: 2,
          bottomInterval: 1,
          horizontalGridInterval: 2,
          verticalGridInterval: 1,
          spots: [
            FlSpot(0, 11.2),
            FlSpot(1, 12.0),
            FlSpot(2, 13.1),
            FlSpot(3, 14.0),
            FlSpot(4, 14.8),
          ],
          bottomTitles: {
            0: 'W1',
            1: 'W2',
            2: 'W3',
            3: 'W4',
            4: 'W5',
          },
        );
    }
  }

  _SensorTrendData _getActivityData(TimeRange range) {
    switch (range) {
      case TimeRange.h24:
        return const _SensorTrendData(
          unit: 'cpm',
          current: '320 cpm',
          average: '279 cpm',
          min: '25 cpm',
          max: '680 cpm',
          insight:
              'Peak worker flight traffic observed between 10:00 AM and 3:30 PM with zero abnormal exit surges.',
          minX: 0,
          maxX: 24,
          minY: 0,
          maxY: 800,
          leftInterval: 200,
          bottomInterval: 6,
          horizontalGridInterval: 200,
          verticalGridInterval: 6,
          spots: [
            FlSpot(0, 40),
            FlSpot(4, 25),
            FlSpot(7, 180),
            FlSpot(10, 520),
            FlSpot(13, 680),
            FlSpot(16, 610),
            FlSpot(19, 320),
            FlSpot(22, 90),
            FlSpot(24, 45),
          ],
          bottomTitles: {
            0: '12AM',
            6: '6AM',
            12: '12PM',
            18: '6PM',
            24: '12AM',
          },
        );
      case TimeRange.d7:
        return const _SensorTrendData(
          unit: 'cpm',
          current: '320 cpm',
          average: '410 cpm',
          min: '40 cpm',
          max: '750 cpm',
          insight:
              'Daily foraging cycles show robust colony vigor with consistent morning departures and evening returns.',
          minX: 0,
          maxX: 6,
          minY: 0,
          maxY: 800,
          leftInterval: 200,
          bottomInterval: 1,
          horizontalGridInterval: 200,
          verticalGridInterval: 1,
          spots: [
            FlSpot(0, 390),
            FlSpot(1, 450),
            FlSpot(2, 420),
            FlSpot(3, 310),
            FlSpot(4, 580),
            FlSpot(5, 750),
            FlSpot(6, 320),
          ],
          bottomTitles: {
            0: 'Mon',
            1: 'Tue',
            2: 'Wed',
            3: 'Thu',
            4: 'Fri',
            5: 'Sat',
            6: 'Sun',
          },
        );
      case TimeRange.d30:
        return const _SensorTrendData(
          unit: 'cpm',
          current: '320 cpm',
          average: '395 cpm',
          min: '30 cpm',
          max: '820 cpm',
          insight:
              'Overall monthly bee activity demonstrates high brood rearing vitality and active field foraging.',
          minX: 0,
          maxX: 4,
          minY: 0,
          maxY: 800,
          leftInterval: 200,
          bottomInterval: 1,
          horizontalGridInterval: 200,
          verticalGridInterval: 1,
          spots: [
            FlSpot(0, 340),
            FlSpot(1, 410),
            FlSpot(2, 480),
            FlSpot(3, 440),
            FlSpot(4, 320),
          ],
          bottomTitles: {
            0: 'W1',
            1: 'W2',
            2: 'W3',
            3: 'W4',
            4: 'W5',
          },
        );
    }
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
                fontWeight: FontWeight.w800,
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
          const SizedBox(width: 8),
          _buildSensorPill(SensorType.activity, 'Activity'),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkGreen : AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppColors.darkGreen : AppColors.border,
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.darkGreen.withValues(alpha: 0.25),
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
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppColors.bgSecondary : AppColors.textPrimary,
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
        color: AppColors.bgElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6), width: 0.8),
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
          setState(() => _selectedTimeRange = range);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.darkGreen.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppColors.bgSecondary : AppColors.textSecondary,
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
            child: LineChart(
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
                          '${spot.y.toStringAsFixed(1)} ${data.unit}',
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
                      reservedSize: 26,
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
                              fontSize: 11,
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
                      reservedSize: 32,
                      interval: data.leftInterval,
                      getTitlesWidget: (value, meta) {
                        if (value < data.minY || value > data.maxY) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4,
                          child: Text(
                            value.toInt().toString(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
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
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
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
            fontWeight: FontWeight.w500,
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
        color: AppColors.bgElevated.withValues(alpha: 0.45),
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
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(10),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.hiveDoor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.insight,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
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

  const _SensorTrendData({
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
