import 'package:flutter/material.dart';

import '../services/environment_catalog.dart';
import '../services/environment_fallback.dart';
import '../widgets/environment_source.dart';

import '../widgets/bee_image_upload_zone.dart';

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/apiary_model.dart';
import '../services/apiary_service.dart';
import '../services/inference_service.dart';
import '../services/weather_service.dart';
import '../services/IT23183186_colony_assessment_api.dart';
import '../widgets/IT23183186_assessment_card.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/IT23183186_weather_dashboard.dart';
import '../widgets/IT23183186_season_activity.dart';
import 'IT23183186_seasonal_changes_screen.dart';
import 'home_screen.dart';
import 'IT23183186_environment_details_screen.dart';
import 'health_screen.dart';
import 'IT23185302_relocation_assessment_screen.dart';
import 'IT23139930_acoustic_entry.dart';
import '../utils/theme.dart';
import 'IT23183186_disease_risk_screen.dart';
import 'IT23183186_hive_telemetry_screen.dart';
import 'image_model_analysis_screen.dart';
import 'add_hive_screen.dart';
import 'apiary_management_screen.dart';
import 'IT23183186_hive_environment_screen.dart';
import 'IT23183186_colony_workspace_screen.dart';

class EnvironmentDashboardScreen extends StatefulWidget {
  final InferenceService? inferenceService;
  final ApiaryService? apiaryService;
  final WeatherService weatherService;
  final ColonyAssessmentApi assessmentApi;

  const EnvironmentDashboardScreen({
    super.key,
    this.inferenceService,
    this.apiaryService,
    this.weatherService = const WeatherService(),
    this.assessmentApi = const ColonyAssessmentApi(),
  });

  @override
  State<EnvironmentDashboardScreen> createState() =>
      _EnvironmentDashboardScreenState();
}

class _EnvironmentDashboardScreenState
    extends State<EnvironmentDashboardScreen> {
  List<ApiaryModel> _apiaries = [];
  List<HiveModel> _hives = [];
  ApiaryModel? _apiary;
  HiveModel? _hive;
  bool _loadingApiaries = true;
  bool _loadingHives = false;
  String? _hiveError;
  int _weatherRequest = 0;
  int _hiveRequest = 0;

  WeatherService get _weatherService => widget.weatherService;
  ApiaryService get _apiaryService =>
      widget.apiaryService ?? ApiaryService.instance;
  WeatherForecast? _forecast;
  bool _loadingForecast = true;
  String? _forecastError;
  CurrentWeather? _weather;
  EnvironmentalImpact? _impact;
  Map<String, dynamic>? _assessment;
  String? _assessmentError;
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
    _loadApiaries();
  }

  Future<void> _loadApiaries() async {
    setState(() {
      _loadingApiaries = true;
      _hiveError = null;
    });
    try {
      final apiaries = await EnvironmentCatalog.apiaries(_apiaryService);
      if (!mounted) return;
      setState(() {
        _apiaries = apiaries;
        _loadingApiaries = false;
      });
      if (apiaries.isEmpty) {
        setState(() {
          _apiary = null;
          _hive = null;
          _hives = [];
        });
        await _loadWeather();
      } else {
        final saved = _apiaryService.selectedApiary;
        await _selectApiary(
          apiaries.firstWhere(
            (a) => a.id == (_apiary?.id ?? saved?.id),
            orElse: () => apiaries.first,
          ),
          preserveSelection: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingApiaries = false;
        _hiveError = 'Could not load your apiaries. Check your connection and sign-in, then retry.';
      });
      await _loadWeather();
    }
  }

  Future<void> _selectApiary(
    ApiaryModel apiary, {
    bool preserveSelection = false,
  }) async {
    final keepSelection = preserveSelection && _apiary?.id == apiary.id;
    final previousHiveId = keepSelection ? _hive?.id : null;
    final request = ++_hiveRequest;
    ++_weatherRequest;
    setState(() {
      _apiary = apiary;
      _hive = null;
      _hives = [];
      _loadingHives = true;
      _hiveError = null;
      if (!keepSelection) {
        _manualLocation = null;
        _usingDeviceLocation = false;
      }
      _weather = null;
      _impact = null;
      _assessment = null;
      _weatherHistory = const [];
      _forecast = null;
      _forecastError = null;
      _loadingForecast = true;
      _loadingWeather = true;
      _loadingImpact = true;
      _loadingHistory = true;
    });
    try {
      if (!isDemoId(apiary.id)) await _apiaryService.selectApiary(apiary);
      final hives = await EnvironmentCatalog.hives(_apiaryService, apiary.id);
      if (!mounted || request != _hiveRequest) return;
      setState(() {
        _hives = hives;
        _hive =
            hives.where((h) => h.id == previousHiveId).firstOrNull ??
            (hives.isEmpty ? null : hives.first);
        _loadingHives = false;
      });
    } catch (_) {
      if (!mounted || request != _hiveRequest) return;
      setState(() {
        _loadingHives = false;
        _hiveError = 'Could not load hives for this apiary. Tap retry.';
      });
    }
    if (isDemoId(apiary.id)) {
      await EnvironmentFallback.instance.selectDemo(
        apiaryId: apiary.id,
        hiveId: _hive?.id,
      );
    }
    await _loadWeather();
  }

  Future<void> _addHive() async {
    final apiary = _apiary;
    if (apiary == null) return;
    final hive = await Navigator.of(context).push<HiveModel>(
      MaterialPageRoute(builder: (_) => AddHiveScreen(apiary: apiary)),
    );
    if (!mounted || hive == null) return;
    final destination = _apiaries.firstWhere(
      (a) => a.id == hive.apiaryId,
      orElse: () => apiary,
    );
    await _selectApiary(destination);
    if (!mounted) return;
    setState(
      () => _hive = _hives.where((h) => h.id == hive.id).firstOrNull ?? _hive,
    );
    await _loadWeather();
  }

  Widget _yardSelector() => Container(
    padding: const EdgeInsets.all(20),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.hive_outlined, color: AppColors.accent3),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your bee yard',
                style: _style(20, FontWeight.w800, AppColors.darkGreen),
              ),
            ),
            IconButton(
              tooltip: 'Reload saved apiaries and hives',
              onPressed: _loadingApiaries || _loadingHives
                  ? null
                  : _loadApiaries,
              icon: const Icon(Icons.sync_rounded),
            ),
          ],
        ),
        Text(
          'Choose your apiary, then a hive box. Weather uses the saved apiary location.',
          style: _style(12, FontWeight.w400, AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        if (_loadingApiaries)
          const LinearProgressIndicator()
        else if (_apiaries.isEmpty) ...[
          const Text(
            'No saved apiaries yet. Add a location to start your bee yard.',
          ),
          TextButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ApiaryManagementScreen(),
                ),
              );
              if (mounted) _loadApiaries();
            },
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Manage apiaries'),
          ),
        ] else ...[
          if (_apiary != null) ...[
            SourceDot(source: _apiary!.source),
            const SizedBox(height: 10),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('apiary-${_apiary?.id}'),
                initialValue: _apiary?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Apiary location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                items: _apiaries
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          a.locationName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id != null) {
                    _selectApiary(_apiaries.firstWhere((a) => a.id == id));
                  }
                },
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loadingHives)
                    const LinearProgressIndicator()
                  else if (_hives.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: ValueKey('hive-${_apiary?.id}-${_hive?.id}'),
                      initialValue: _hive?.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Hive box',
                        prefixIcon: Icon(Icons.hive_outlined),
                      ),
                      items: _hives
                          .map(
                            (h) => DropdownMenuItem(
                              value: h.id,
                              child: Text(
                                h.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        setState(
                          () => _hive = _hives.firstWhere((h) => h.id == id),
                        );
                        if (isDemoId(id)) {
                          EnvironmentFallback.instance.selectDemo(
                            apiaryId: _apiary?.id,
                            hiveId: id,
                          );
                        }
                        _loadWeather();
                      },
                    )
                  else if (_hiveError == null)
                    const Text('No hives at this location yet.'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.hive_outlined, size: 16),
                label: Text('${_hives.length} saved hives'),
              ),
              if (_hive != null)
                Chip(
                  avatar: const Icon(Icons.grid_view_rounded, size: 16),
                  label: Text('${_hive!.numFrames} frames'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _loadingHives ? null : _addHive,
                icon: const Icon(Icons.add),
                label: const Text('Add hive'),
              ),
              if (_hive != null)
                OutlinedButton.icon(
                  onPressed: () => _open(
                    context,
                    IT23183186HiveEnvironmentScreen(
                      hive: _hive!,
                      apiary: _apiary!,
                    ),
                  ),
                  icon: const Icon(Icons.eco_outlined),
                  label: const Text('View hive environment'),
                ),
              if (_hive != null)
                FilledButton.tonalIcon(
                  onPressed: () => _open(
                    context,
                    IT23183186ColonyWorkspaceScreen(
                      hive: _hive!,
                      apiary: _apiary!,
                    ),
                  ),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('Colony workspace'),
                ),
            ],
          ),
        ],
        if (_hiveError != null) ...[
          const SizedBox(height: 10),
          Text(
            _hiveError!,
            style: _style(12, FontWeight.w500, AppColors.error),
          ),
          TextButton(
            onPressed: _loadingApiaries || _loadingHives
                ? null
                : () => _apiary == null
                      ? _loadApiaries()
                      : _selectApiary(_apiary!),
            child: const Text('Retry'),
          ),
        ],
      ],
    ),
  );

  Widget _weatherLocationCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on_outlined, color: AppColors.accent3),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weather location',
                    style: _style(12, FontWeight.w600, AppColors.textSecondary),
                  ),
                  Text(
                    _weather?.locationName ??
                        (_manualLocation != null
                            ? _locationQuery
                            : _apiary?.locationName ?? _locationQuery),
                    style: _style(16, FontWeight.w700, AppColors.darkGreen),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _locationStatus ?? 'Uses your saved apiary location.',
          style: _style(12, FontWeight.w400, AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _loadingWeather ? null : _editLocation,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: const Text('Change location'),
            ),
            OutlinedButton.icon(
              onPressed: _loadingWeather ? null : _useDeviceLocation,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('Use my location'),
            ),
            if (_manualLocation != null && _apiary != null)
              TextButton.icon(
                onPressed: _loadingWeather
                    ? null
                    : () {
                        setState(() {
                          _manualLocation = null;
                          _usingDeviceLocation = false;
                        });
                        _loadWeather();
                      },
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Use saved apiary'),
              ),
          ],
        ),
        if (_manualLocation != null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Weather preview only. Your saved apiary and hive stay unchanged.',
              style: TextStyle(fontSize: 12, color: AppColors.info),
            ),
          ),
      ],
    ),
  );

  Future<void> _loadForecast(String location, int request) async {
    try {
      final forecast = await _weatherService.fetchForecast(location);
      if (!mounted || request != _weatherRequest) return;
      setState(() {
        _forecast = forecast;
        _loadingForecast = false;
      });
    } catch (_) {
      if (!mounted || request != _weatherRequest) return;
      setState(() {
        _loadingForecast = false;
        _forecastError = 'Forecast unavailable. Check the weather service connection and account access.';
      });
    }
  }

  Future<void> _loadWeather({String? location}) async {
    final request = ++_weatherRequest;
    final hiveId = _hive?.id;
    final apiary = _apiary;
    final gps = apiary?.gpsLocation?.trim();
    final resolvedLocation =
        location ??
        _manualLocation ??
        (gps != null && gps.isNotEmpty
            ? gps
            : apiary != null
            ? '${apiary.locationName}, Sri Lanka'
            : await _deviceLocationQuery() ?? 'Colombo, Sri Lanka');
    if (!mounted || request != _weatherRequest) return;
    if (location == null && _manualLocation == null && apiary != null) {
      _locationStatus = gps != null && gps.isNotEmpty
          ? 'Using saved apiary GPS coordinates'
          : 'Using saved apiary location';
    }
    _locationQuery = resolvedLocation;
    setState(() {
      _forecast = null;
      _forecastError = null;
      _loadingForecast = true;
      _loadingWeather = true;
      _weatherError = null;
      _assessment = null;
      _assessmentError = null;
      _weather = null;
      _impact = null;
      _weatherHistory = const [];
      _loadingImpact = true;
      _impactError = null;
      _loadingHistory = true;
      _historyError = null;
    });
    unawaited(_loadForecast(resolvedLocation, request));
    try {
      final result = await _weatherService.fetchImpact(resolvedLocation);
      if (!mounted || request != _weatherRequest) return;
      setState(() {
        _weather = result.weather;
        _impact = result.analysis;
        _loadingWeather = false;
        _loadingImpact = false;
      });
    } catch (error) {
      if (!mounted || request != _weatherRequest) return;
      setState(() {
        _weatherError = error.toString();
        _impactError = error.toString();
        _loadingWeather = false;
        _loadingImpact = false;
      });
    }
    try {
      final snapshot = await widget.assessmentApi.fetch(
        location: resolvedLocation,
        hiveId: hiveId,
      );
      if (mounted && request == _weatherRequest) {
        setState(
          () => _assessment = Map<String, dynamic>.from(
            snapshot['assessment'] as Map,
          ),
        );
      }
    } catch (_) {
      if (mounted && request == _weatherRequest) {
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
      if (!mounted || request != _weatherRequest) return;
      setState(() {
        _weatherHistory = history.days;
        _loadingHistory = false;
      });
    } catch (error) {
      if (!mounted || request != _weatherRequest) return;
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
    final previousStatus = _locationStatus;
    final previousDevice = _usingDeviceLocation;
    final query = await _deviceLocationQuery();
    if (!mounted) return;
    if (query == null) {
      final message = _locationStatus;
      setState(() {
        _usingDeviceLocation = previousDevice;
        _locationStatus = previousStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'Current location unavailable.')),
      );
      return;
    }
    _manualLocation = query;
    await _loadWeather(location: query);
  }

  Future<void> _editLocation() async {
    var draftLocation = _locationQuery;
    final location = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgPrimary,
        title: Text(
          'Weather location',
          style: _style(18, FontWeight.w700, AppColors.textPrimary),
        ),
        content: TextFormField(
          initialValue: draftLocation,
          onChanged: (value) => draftLocation = value,
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
            onPressed: () => Navigator.pop(context, draftLocation.trim()),
            child: const Text('Update'),
          ),
        ],
      ),
    );
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
  Widget build(BuildContext context) => EnvironmentRecovery(
    needed: () =>
        _apiary?.source == 'demo' ||
        _weather?.source != 'live' ||
        (_assessment != null && dataSource(_assessment) != 'live'),
    onRetry: _loadApiaries,
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) => Scaffold(
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
                              'A little closer to your bee yard',
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
                  _weatherLocationCard(),
                  const SizedBox(height: 20),
                  _yardSelector(),
                  const SizedBox(height: 20),
                  EnvironmentWeatherDashboard(
                    showDetails: false,
                    weather: _weather,
                    forecast: _forecast,
                    history: _weatherHistory,
                    loading: _loadingWeather,
                    loadingForecast: _loadingForecast,
                    loadingHistory: _loadingHistory,
                    error: _weatherError,
                    forecastError: _forecastError,
                    historyError: _historyError,
                    locationQuery: _locationQuery,
                    onRetry: () => _loadWeather(location: _locationQuery),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _open(
                        context,
                        IT23183186EnvironmentDetailsScreen(
                          locationQuery: _locationQuery,
                          weatherService: _weatherService,
                        ),
                      ),
                      icon: const Icon(Icons.insights_outlined),
                      label: const Text('View more about environment'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    'Weather observations',
                    'Hive readings',
                    () => _open(
                      context,
                      HiveTelemetryScreen(
                        location: _locationQuery,
                        hiveId: _hive?.id,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Season & colony activity',
                    style: _style(18, FontWeight.w800, AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  _impactCard(),
                  const SizedBox(height: 24),
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
                                      assessmentApi: widget.assessmentApi,
                                      location: _locationQuery,
                                      hiveId: _hive?.id,
                                      inferenceService: widget.inferenceService,
                                    ),
                                  ),
                                ),
                                if (_assessment != null)
                                  ColonyAssessmentCard(
                                    assessment: _assessment!,
                                    compact: true,
                                    onViewAll: () => _open(
                                      context,
                                      DiseaseRiskScreen(
                                        assessmentApi: widget.assessmentApi,
                                        location: _locationQuery,
                                        hiveId: _hive?.id,
                                        inferenceService:
                                            widget.inferenceService,
                                      ),
                                    ),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _statusPanel(
                                        _assessmentError == null
                                            ? Icons.hourglass_empty
                                            : Icons.error_outline,
                                        'Evidence status',
                                        _assessmentError ?? 'Checking available observations...',
                                      ),
                                      if (_assessmentError == null)
                                        const LinearProgressIndicator()
                                      else
                                        TextButton.icon(
                                          onPressed: () => _loadWeather(),
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Retry monitoring'),
                                        ),
                                      FilledButton.icon(
                                        onPressed: () => _open(
                                          context,
                                          DiseaseRiskScreen(
                                            assessmentApi: widget.assessmentApi,
                                            location: _locationQuery,
                                            hiveId: _hive?.id,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.list_alt_outlined,
                                        ),
                                        label: const Text(
                                          'View all monitoring suggestions',
                                        ),
                                      ),
                                    ],
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
                                  'Bee Disease Identification',
                                  'Upload',
                                  () => _open(
                                    context,
                                    ImageModelAnalysisScreen(
                                      location: _locationQuery,
                                      hiveId: _hive?.id,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgCard,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppColors.border),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.textPrimary.withValues(
                                          alpha: .035,
                                        ),
                                        blurRadius: 18,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.asset(
                                          'lib/utils/images/05_bees_on_honeycomb.png',
                                          height: 128,
                                          fit: BoxFit.cover,
                                          semanticLabel: 'Bee on honeycomb; illustrative image, not a disease example',
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      const Text(
                                        'Explore your bee and hive photos',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.darkGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Choose an individual bee photo below, or open all identification tools for hive-frame photos. Model findings are not confirmed diagnoses.',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      BeeImageUploadZone(
                                        onSelected: (file) => _open(
                                          context,
                                          ImageModelAnalysisScreen(
                                            location: _locationQuery,
                                            hiveId: _hive?.id,
                                            initialOutside: file,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton.icon(
                                        onPressed: () => _open(
                                          context,
                                          ImageModelAnalysisScreen(
                                            location: _locationQuery,
                                            hiveId: _hive?.id,
                                          ),
                                        ),
                                        icon: const Icon(Icons.arrow_forward),
                                        label: const Text(
                                          'View all Disease Identification',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 16),
                  Text(
                    'Weather describes the selected location. Hive readings need connected sensors. Alerts and image results guide inspection; they do not confirm disease.',
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
    return SeasonActivityPanel(
      impact: impact,
      weather: _weather,
      onViewMore: () => _open(
        context,
        IT23183186SeasonalChangesScreen(
          impact: impact,
          weather: _weather,
          location:
              _weather?.locationName ?? _apiary?.locationName ?? _locationQuery,
        ),
      ),
    );
  }
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
    Expanded(
      child: Text(
        title,
        style: _style(17, FontWeight.w800, AppColors.darkGreen),
      ),
    ),
    TextButton(
      onPressed: onTap,
      child: Text(action, style: _style(12, FontWeight.w700, AppColors.blue)),
    ),
  ],
);
