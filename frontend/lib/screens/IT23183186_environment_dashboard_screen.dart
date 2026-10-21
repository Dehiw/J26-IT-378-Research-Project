import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/apiary_model.dart';
import '../services/apiary_service.dart';
import '../services/inference_service.dart';
import '../services/weather_service.dart';
import '../services/IT23183186_colony_assessment_api.dart';
import '../widgets/IT23183186_assessment_card.dart';
import '../widgets/main_bottom_nav.dart';
import 'home_screen.dart';
import 'health_screen.dart';
import 'IT23185302_relocation_assessment_screen.dart';
import 'IT23139930_acoustic_entry.dart';
import '../utils/theme.dart';
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
  Map<String, dynamic>? _assessment;
  String? _assessmentError;
  List<HistoricalWeatherDay> _weatherHistory = const [];
  Map<String, dynamic> _historyAnalysis = const {};
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
      _assessment = null;
      _assessmentError = null;
      _weather = null;
      _impact = null;
      _weatherHistory = const [];
      _historyAnalysis = const {};
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
      final snapshot = await const ColonyAssessmentApi().fetch(
        location: resolvedLocation,
      );
      if (mounted) {
        setState(
          () => _assessment = Map<String, dynamic>.from(
            snapshot['assessment'] as Map,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _assessmentError =
              'Monitoring alerts unavailable. Open risk overview to retry.',
        );
      }
    }
    try {
      final history = await _weatherService.fetchHistoryAnalysis(
        resolvedLocation,
      );
      if (!mounted) return;
      setState(() {
        _weatherHistory = history.days;
        _historyAnalysis = history.analysis;
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

  void _onNavTapped(int index) {
    if (index == 4) return;
    final navigator = Navigator.of(context);
    switch (index) {
      case 0:
        navigator.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) =>
                HomeScreen(inferenceService: widget.inferenceService),
          ),
          (_) => false,
        );
      case 1:
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                HealthScreen(inferenceService: widget.inferenceService),
          ),
        );
      case 2:
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const RelocationAssessmentScreenIT23185302(),
          ),
        );
      case 3:
        openSoundMonitor(context, inferenceService: widget.inferenceService);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: MainBottomNav(currentIndex: 4, onTap: _onNavTapped),
    backgroundColor: AppColors.bgPrimary,
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _loadWeather(location: _locationQuery),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.badgeLeafBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.eco_outlined,
                          color: AppColors.accent3,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Environment',
                              style: _style(
                                26,
                                FontWeight.w800,
                                AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Your apiary, in context',
                              style: _style(
                                13,
                                FontWeight.w500,
                                AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh observations',
                        onPressed: _loadingWeather
                            ? null
                            : () => _loadWeather(location: _locationQuery),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: _cardDecoration(),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.accent3,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _weather?.locationName ??
                                    ApiaryService
                                        .instance
                                        .selectedApiary
                                        ?.locationName ??
                                    (_usingDeviceLocation
                                        ? 'Current GPS location'
                                        : _locationQuery),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _style(
                                  14,
                                  FontWeight.w700,
                                  AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                _locationStatus ??
                                    'Choose your apiary location',
                                maxLines: 2,
                                style: _style(
                                  11,
                                  FontWeight.w400,
                                  AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit weather location',
                          onPressed: _editLocation,
                          icon: const Icon(Icons.edit_location_alt_outlined),
                        ),
                        IconButton(
                          tooltip: 'Use device GPS',
                          onPressed: _useDeviceLocation,
                          icon: const Icon(Icons.my_location_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _weatherHero(),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 820;
                      final width = wide
                          ? (constraints.maxWidth - 20) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          SizedBox(
                            width: width,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle(
                                  'Colony monitoring',
                                  'Open',
                                  () => _open(
                                    context,
                                    DiseaseRiskScreen(
                                      location: _locationQuery,
                                      inferenceService: widget.inferenceService,
                                    ),
                                  ),
                                ),
                                if (_assessment != null)
                                  ColonyAssessmentCard(
                                    assessment: _assessment!,
                                    compact: true,
                                  )
                                else
                                  _statusPanel(
                                    Icons.shield_outlined,
                                    'Evidence status',
                                    _assessmentError ??
                                        'Checking available observations...',
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle(
                                  'Image insights',
                                  'Upload',
                                  () => _open(
                                    context,
                                    ImageModelAnalysisScreen(
                                      location: _locationQuery,
                                    ),
                                  ),
                                ),
                                _statusPanel(
                                  Icons.add_photo_alternate_outlined,
                                  'See what your photos can tell you',
                                  'Upload an individual bee photo or a hive-frame image. Each uses its own model; supported findings remain separate.',
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () => _open(
                                      context,
                                      ImageModelAnalysisScreen(
                                        location: _locationQuery,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.add_a_photo_outlined,
                                    ),
                                    label: const Text(
                                      'Analyze bee or frame images',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    'Weather observations',
                    'Hive readings',
                    () => _open(context, const HiveTelemetryScreen()),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width =
                          (constraints.maxWidth -
                              (constraints.maxWidth < 580 ? 12 : 36)) /
                          (constraints.maxWidth < 580 ? 2 : 4);
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: width,
                            child: _MetricCard(
                              icon: Icons.thermostat_outlined,
                              label: 'Temperature',
                              value: _weather == null
                                  ? '--'
                                  : '${_weather!.temperatureC.toStringAsFixed(1)} C',
                              note: 'Outdoor air',
                              color: AppColors.accent2,
                              onTap: () =>
                                  _open(context, const HiveTelemetryScreen()),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _MetricCard(
                              icon: Icons.water_drop_outlined,
                              label: 'Humidity',
                              value: _weather == null
                                  ? '--'
                                  : '${_weather!.humidityPercent}%',
                              note: 'Outdoor relative humidity',
                              color: AppColors.blue,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _MetricCard(
                              icon: Icons.grain_rounded,
                              label: 'Precipitation',
                              value: _weather == null
                                  ? '--'
                                  : '${_weather!.precipitationMm.toStringAsFixed(1)} mm',
                              note: 'Current observation',
                              color: AppColors.accent3,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _MetricCard(
                              icon: Icons.air_rounded,
                              label: 'Wind',
                              value: _weather == null
                                  ? '--'
                                  : '${_weather!.windKph.toStringAsFixed(1)} km/h',
                              note: _weather?.windDirection ?? 'Outdoor wind',
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth >= 820
                          ? (constraints.maxWidth - 20) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          SizedBox(
                            width: width,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Season & colony activity',
                                  style: _style(
                                    18,
                                    FontWeight.w800,
                                    AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _impactCard(),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Last 7 days',
                                  style: _style(
                                    18,
                                    FontWeight.w800,
                                    AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _historyCard(),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => _open(context, const ForageMapScreen()),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Explore forage map (illustrative)'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Outdoor observations via WeatherAPI. Hive readings require a selected hive. Image findings and monitoring alerts are preliminary decision support.',
                    style: _style(11, FontWeight.w400, AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _statusPanel(IconData icon, String title, String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accent3, size: 28),
        const SizedBox(height: 12),
        Text(title, style: _style(15, FontWeight.w700, AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(
          message,
          style: _style(12, FontWeight.w400, AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _weatherHero() {
    final unavailable = !_loadingWeather && _weather == null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: unavailable ? AppColors.bgElevated : AppColors.accent3,
        borderRadius: BorderRadius.circular(24),
        border: unavailable ? Border.all(color: AppColors.border) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unavailable
                      ? 'WEATHER CONNECTION'
                      : 'CURRENT OUTDOOR CONDITIONS',
                  style: _style(
                    11,
                    FontWeight.w700,
                    unavailable ? AppColors.textSecondary : AppColors.bgPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _loadingWeather
                      ? 'Loading observations...'
                      : unavailable
                      ? 'Weather is temporarily unavailable'
                      : '${_weather!.temperatureC.toStringAsFixed(1)} C',
                  style: _style(
                    unavailable ? 22 : 32,
                    FontWeight.w800,
                    unavailable ? AppColors.textPrimary : AppColors.bgPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadingWeather
                      ? 'Looking up your selected location.'
                      : unavailable
                      ? (_weatherError ??
                            'Check the backend connection and try again.')
                      : '${_weather!.condition} | Updated ${_weather!.updatedAt}',
                  style: _style(
                    13,
                    FontWeight.w500,
                    unavailable ? AppColors.textSecondary : AppColors.bgPrimary,
                  ),
                ),
                if (unavailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: () => _loadWeather(location: _locationQuery),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            unavailable ? Icons.cloud_off_outlined : Icons.cloud_outlined,
            size: 40,
            color: unavailable ? AppColors.warning : AppColors.bgPrimary,
          ),
        ],
      ),
    );
  }

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
          if (_historyAnalysis.isNotEmpty) ...[
            Text(
              'Observed rainfall: ${_historyAnalysis['total_precipitation_mm'] ?? 'unavailable'} mm across ${_historyAnalysis['rainfall_days_available'] ?? 0} days',
            ),
            Text('${_historyAnalysis['interpretation'] ?? ''}'),
            Text(
              '${_historyAnalysis['limitation'] ?? ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
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
          _impactItem('Population', impact.population),
          _impactItem('Development conditions', impact.developmentSuitability),
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
