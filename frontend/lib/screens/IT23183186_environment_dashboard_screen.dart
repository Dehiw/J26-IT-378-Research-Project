import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/apiary_model.dart';
import '../services/apiary_service.dart';
import '../services/inference_service.dart';
import '../services/weather_service.dart';
import '../utils/theme.dart';
import 'IT23183186_disease_assessment_screen.dart';
import 'IT23183186_disease_check_screen.dart';
import 'IT23183186_disease_risk_screen.dart';
import 'IT23183186_forage_map_screen.dart';
import 'IT23183186_hive_telemetry_screen.dart';
import 'image_model_analysis_screen.dart';

class EnvironmentDashboardScreen extends StatefulWidget {
  final InferenceService? inferenceService;

  const EnvironmentDashboardScreen({super.key, this.inferenceService});

  @override
  State<EnvironmentDashboardScreen> createState() =>
      _EnvironmentDashboardScreenState();
}

class _EnvironmentDashboardScreenState
    extends State<EnvironmentDashboardScreen> {
  final WeatherService _weatherService = const WeatherService();
  CurrentWeather? _weather;
  EnvironmentalImpact? _impact;
  List<HistoricalWeatherDay> _weatherHistory = const [];
  String? _weatherError;
  String? _impactError;
  String? _historyError;
  String? _locationStatus;
  String _locationQuery = 'Colombo, Sri Lanka';
  String? _manualLocation;
  bool _loadingWeather = true;
  bool _loadingImpact = true;
  bool _loadingHistory = true;
  bool _usingDeviceLocation = false;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather({String? location}) async {
    final ApiaryModel? apiary = ApiaryService.instance.selectedApiary;
    final gps = apiary?.gpsLocation?.trim();
    final resolvedLocation =
        location ??
        _manualLocation ??
        (gps != null && gps.isNotEmpty ? gps : await _deviceLocationQuery()) ??
        (apiary == null
            ? 'Colombo, Sri Lanka'
            : '${apiary.locationName}, Sri Lanka');
    if (!mounted) return;
    if (location == null &&
        _manualLocation == null &&
        gps != null &&
        gps.isNotEmpty) {
      _locationStatus = 'Using saved apiary GPS coordinates';
    }
    _locationQuery = resolvedLocation;
    setState(() {
      _loadingWeather = true;
      _weatherError = null;
      _loadingImpact = true;
      _impactError = null;
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final result = await _weatherService.fetchImpact(resolvedLocation);
      if (!mounted) return;
      setState(() {
        _weather = result.weather;
        _impact = result.analysis;
        _loadingWeather = false;
        _loadingImpact = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _weatherError = error.toString();
        _impactError = error.toString();
        _loadingWeather = false;
        _loadingImpact = false;
      });
    }
    try {
      final history = await _weatherService.fetchHistory(resolvedLocation);
      if (!mounted) return;
      setState(() {
        _weatherHistory = history;
        _loadingHistory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyError = error.toString();
        _loadingHistory = false;
      });
    }
  }

  Future<String?> _deviceLocationQuery() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationStatus =
            'Location services are off; using the saved location.';
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationStatus =
            'Location permission unavailable; using the saved location.';
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _usingDeviceLocation = true;
      _locationStatus = 'Weather location from device GPS';
      return '${position.latitude},${position.longitude}';
    } catch (_) {
      _locationStatus =
          'Could not read device location; using the saved location.';
      return null;
    }
  }

  Future<void> _useDeviceLocation() async {
    _manualLocation = null;
    _usingDeviceLocation = false;
    final query = await _deviceLocationQuery();
    if (!mounted) return;
    if (query == null) {
      setState(() {});
      return;
    }
    await _loadWeather(location: query);
  }

  Future<void> _editLocation() async {
    final controller = TextEditingController(text: _locationQuery);
    final location = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgPrimary,
        title: Text(
          'Weather location',
          style: _style(18, FontWeight.w700, AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'City or latitude,longitude',
            hintText: 'Kandy or 7.2906,80.6337',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (location == null || location.isEmpty) return;
    _manualLocation = location;
    _usingDeviceLocation = false;
    _locationStatus = 'Weather location entered manually';
    await _loadWeather(location: location);
  }

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
                    'Good morning ðŸ',
                    style: _style(20, FontWeight.w800, AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh weather',
                  onPressed: _loadWeather,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: 'Use device GPS location',
                  onPressed: _useDeviceLocation,
                  icon: const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
            Center(
              child: InkWell(
                onTap: _editLocation,
                borderRadius: BorderRadius.circular(18),
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
                        _weather?.locationName ?? _locationQuery,
                        style: _style(
                          13,
                          FontWeight.w600,
                          AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        _usingDeviceLocation
                            ? Icons.my_location_rounded
                            : Icons.edit_location_alt_outlined,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_locationStatus != null) ...[
              const SizedBox(height: 5),
              Text(
                _locationStatus!,
                style: _style(11, FontWeight.w500, AppColors.textSecondary),
              ),
            ],
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
                          'Current outdoor conditions',
                          style: _style(
                            14,
                            FontWeight.w500,
                            AppColors.bgPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _weather?.condition ??
                              (_loadingWeather
                                  ? 'Loading weather…'
                                  : 'Weather unavailable'),
                          style: _style(
                            17,
                            FontWeight.w700,
                            AppColors.bgPrimary,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _weather == null
                              ? (_weatherError ??
                                    'WeatherAPI data for this location')
                              : 'Updated ${_weather!.updatedAt}',
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
                            TextSpan(
                              text: _weather == null
                                  ? '--\n'
                                  : '${_weather!.humidityPercent}\n',
                            ),
                            TextSpan(
                              text: '% RH',
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
            const SizedBox(height: 24),
            _sectionTitle(
              'Hive Health',
              'Disease check',
              () => _open(
                context,
                DiseaseCheckScreen(inferenceService: widget.inferenceService),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.health_and_safety_outlined,
                    label: 'Disease check',
                    value: 'Open',
                    note: 'View available evidence',
                    color: AppColors.warning,
                    onTap: () => _open(
                      context,
                      DiseaseCheckScreen(
                        inferenceService: widget.inferenceService,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.assessment_outlined,
                    label: 'Risk overview',
                    value: 'Open',
                    note: 'See baseline assessment',
                    color: AppColors.accent3,
                    onTap: () => _open(
                      context,
                      DiseaseRiskScreen(
                        inferenceService: widget.inferenceService,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _open(
                context,
                DiseaseAssessmentScreen(
                  inferenceService: widget.inferenceService,
                ),
              ),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Upload hive images'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => _open(context, const ImageModelAnalysisScreen()),
              icon: const Icon(Icons.hub_outlined),
              label: const Text('Analyze outside and inside images'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.thermostat_rounded,
                    label: 'Temperature',
                    value: _weather == null
                        ? (_loadingWeather ? 'Loading…' : 'Unavailable')
                        : '${_weather!.temperatureC.toStringAsFixed(1)}°C',
                    note: _weather == null
                        ? 'WeatherAPI'
                        : 'Feels like ${_weather!.feelsLikeC.toStringAsFixed(1)}°C',
                    color: AppColors.accent3,
                    onTap: () => _open(context, const HiveTelemetryScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.water_drop_outlined,
                    label: 'Humidity',
                    value: _weather == null
                        ? (_loadingWeather ? 'Loading…' : 'Unavailable')
                        : '${_weather!.humidityPercent}%',
                    note: _weather == null
                        ? 'WeatherAPI'
                        : 'Current outdoor humidity',
                    color: AppColors.blue,
                    onTap: () => _open(context, const HiveTelemetryScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.cloud_outlined,
                    label: 'Rainfall',
                    value: _weather == null
                        ? (_loadingWeather ? 'Loading…' : 'Unavailable')
                        : '${_weather!.precipitationMm.toStringAsFixed(1)} mm',
                    note: _weather == null
                        ? 'WeatherAPI'
                        : 'Current precipitation',
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
            _sectionTitle(
              'Environmental Impact Analysis',
              'Refresh',
              _loadWeather,
            ),
            const SizedBox(height: 8),
            _impactCard(),
            const SizedBox(height: 18),
            _sectionTitle('7-Day Weather History', 'Refresh', _loadWeather),
            const SizedBox(height: 8),
            _historyCard(),
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
                            'Weather conditions are from WeatherAPI. Other risk insights require local sensor data.',
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
              title: _weather == null
                  ? 'Weather data status'
                  : 'Wind ${_weather!.windKph.toStringAsFixed(0)} km/h · UV ${_weather!.uvIndex.toStringAsFixed(1)}',
              subtitle: _weather == null
                  ? (_weatherError ?? 'Loading current conditions')
                  : '${_weather!.windDirection} · ${_weather!.locationName} · ${_weather!.updatedAt}',
              color: AppColors.accent3,
            ),
            const SizedBox(height: 24),
            Text(
              _weatherError == null
                  ? 'Temperature, humidity and weather data via WeatherAPI. Forage and telemetry cards are illustrative.'
                  : _weatherError!,
              style: _style(11, FontWeight.w500, AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _historyCard() {
    if (_loadingHistory) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_weatherHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Text(
          _historyError ?? 'No historical weather data is available.',
          style: _style(12, FontWeight.w500, AppColors.textSecondary),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _weatherTrend(
            'Average temperature (°C)',
            _weatherHistory.map((day) => day.averageTemperatureC).toList(),
            AppColors.accent2,
          ),
          _weatherTrend(
            'Average humidity (%)',
            _weatherHistory.map((day) => day.averageHumidityPercent).toList(),
            AppColors.blue,
          ),
          _weatherTrend(
            'Rainfall (mm/day)',
            _weatherHistory.map((day) => day.precipitationMm).toList(),
            AppColors.accent3,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: _style(11, FontWeight.w700, AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Avg °C',
                    textAlign: TextAlign.end,
                    style: _style(11, FontWeight.w700, AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Humidity',
                    textAlign: TextAlign.end,
                    style: _style(11, FontWeight.w700, AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Rain mm',
                    textAlign: TextAlign.end,
                    style: _style(11, FontWeight.w700, AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          for (final day in _weatherHistory)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      day.date.substring(5),
                      style: _style(12, FontWeight.w600, AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      day.averageTemperatureC.toStringAsFixed(1),
                      textAlign: TextAlign.end,
                      style: _style(12, FontWeight.w500, AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${day.averageHumidityPercent.toStringAsFixed(0)}%',
                      textAlign: TextAlign.end,
                      style: _style(12, FontWeight.w500, AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      day.precipitationMm.toStringAsFixed(1),
                      textAlign: TextAlign.end,
                      style: _style(12, FontWeight.w500, AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _historyError == null
                  ? 'Historical WeatherAPI data; not locally saved sensor readings.'
                  : 'History unavailable: $_historyError',
              style: _style(10, FontWeight.w500, AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherTrend(String label, List<double> values, Color color) {
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final margin = ((maximum - minimum) * .15)
        .clamp(.5, double.infinity)
        .toDouble();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _style(11, FontWeight.w700, AppColors.textPrimary),
          ),
          SizedBox(
            height: 58,
            child: LineChart(
              LineChartData(
                minY: minimum - margin,
                maxY: maximum + margin,
                minX: 0,
                maxX: (values.length - 1).toDouble(),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: margin,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border.withValues(alpha: .6),
                    strokeWidth: 1,
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var index = 0; index < values.length; index++)
                        FlSpot(index.toDouble(), values[index]),
                    ],
                    isCurved: false,
                    color: color,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: .10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactCard() {
    final impact = _impact;
    if (_loadingImpact) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (impact == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Text(
          _impactError ?? 'Environmental analysis is unavailable.',
          style: _style(12, FontWeight.w500, AppColors.textSecondary),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            impact.season,
            style: _style(17, FontWeight.w800, AppColors.textPrimary),
          ),
          Text(
            impact.seasonPeriod,
            style: _style(12, FontWeight.w600, AppColors.accent3),
          ),
          const SizedBox(height: 5),
          Text(
            impact.regionalContext,
            style: _style(11, FontWeight.w500, AppColors.textSecondary),
          ),
          const Divider(height: 22),
          Text(
            'Outdoor conditions',
            style: _style(14, FontWeight.w700, AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            impact.environmentalSummary,
            style: _style(12, FontWeight.w400, AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          _impactItem('Bee activity', impact.beeActivity),
          _impactItem('Colony growth', impact.colonyGrowth),
          _impactItem('Food availability', impact.foodAvailability),
          const SizedBox(height: 8),
          Text(
            'Recommended actions',
            style: _style(13, FontWeight.w700, AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          for (final recommendation in impact.recommendations)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 5, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: _style(
                        11,
                        FontWeight.w500,
                        AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Source: ${impact.dataQuality['weather'] ?? 'WeatherAPI'} · ${impact.dataQuality['weather_observed_at'] ?? _weather?.updatedAt ?? ''}',
            style: _style(10, FontWeight.w600, AppColors.textSecondary),
          ),
          const SizedBox(height: 3),
          Text(
            'Preliminary decision support. Regional context is approximate; this does not diagnose colony health.',
            style: _style(10, FontWeight.w500, AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _impactItem(String title, Map<String, dynamic> data) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _style(12, FontWeight.w700, AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            data['assessment']?.toString() ?? 'Unknown',
            style: _style(12, FontWeight.w600, AppColors.accent3),
          ),
          const SizedBox(height: 2),
          Text(
            data['reason']?.toString() ?? '',
            style: _style(11, FontWeight.w400, AppColors.textSecondary),
          ),
        ],
      ),
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
