import 'package:flutter/material.dart';

import '../widgets/environment_source.dart';

import 'package:google_fonts/google_fonts.dart';

import '../models/apiary_model.dart';
import '../services/weather_service.dart';
import '../services/environment_fallback.dart';
import '../services/IT23183186_colony_assessment_api.dart';
import '../utils/theme.dart';
import '../widgets/IT23183186_assessment_card.dart';
import 'image_model_analysis_screen.dart';
import 'IT23183186_environment_history_screen.dart';
import 'IT23183186_colony_workspace_screen.dart';

/// A saved hive and its apiary location, with independent outdoor/colony sources.
class IT23183186HiveEnvironmentScreen extends StatefulWidget {
  final WeatherService weatherService;
  final ColonyAssessmentApi assessmentApi;
  final HiveModel hive;
  final ApiaryModel apiary;
  const IT23183186HiveEnvironmentScreen({
    super.key,
    required this.hive,
    required this.apiary,
    this.weatherService = const WeatherService(),
    this.assessmentApi = const ColonyAssessmentApi(),
  });

  @override
  State<IT23183186HiveEnvironmentScreen> createState() =>
      _HiveEnvironmentState();
}

class _HiveEnvironmentState extends State<IT23183186HiveEnvironmentScreen> {
  WeatherImpactResponse? _conditions;
  Map<String, dynamic>? _assessment;
  String? _weatherError;
  String? _assessmentError;
  bool _loading = true;
  bool _saving = false;
  String? _saveStatus;
  int _request = 0;

  String get _location {
    final gps = widget.apiary.gpsLocation?.trim();
    return gps != null && gps.isNotEmpty
        ? gps
        : '${widget.apiary.locationName}, Sri Lanka';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _conditions = null;
      _assessment = null;
      _weatherError = null;
      _assessmentError = null;
    });
    await Future.wait([
      (() async {
        try {
          final result = await widget.weatherService.fetchImpact(_location);
          if (mounted && request == _request) {
            setState(() => _conditions = result);
          }
        } catch (_) {
          if (mounted && request == _request) {
            setState(
              () => _weatherError =
                  'Outdoor conditions could not be loaded. Pull down to retry.',
            );
          }
        }
      })(),
      (() async {
        try {
          final result = await widget.assessmentApi.fetch(
            location: _location,
            hiveId: widget.hive.id,
          );
          if (mounted && request == _request) {
            setState(
              () => _assessment = Map<String, dynamic>.from(
                result['assessment'] as Map,
              ),
            );
          }
        } catch (_) {
          if (mounted && request == _request) {
            setState(
              () => _assessmentError = 'Hive monitoring is unavailable. Check your connection and sign-in, then retry.',
            );
          }
        }
      })(),
    ]);
    if (mounted && request == _request) setState(() => _loading = false);
  }

  Future<void> _saveSnapshot() async {
    setState(() {
      _saving = true;
      _saveStatus = null;
    });
    try {
      final record = await widget.assessmentApi.saveSnapshot(
        hiveId: widget.hive.id,
      );
      if (mounted) {
        setState(
          () => _saveStatus = record['local_only'] == true
              ? 'Demo saved on this device only. Backend save did not complete.'
              : 'Snapshot saved to your hive history.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveStatus =
              'Snapshot was not saved. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TextStyle _text(
    double size,
    FontWeight weight, [
    Color color = AppColors.textPrimary,
  ]) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.45,
  );

  Widget _card(Widget child, {Color color = AppColors.bgCard}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) => EnvironmentRecovery(
    needed: () =>
        _conditions?.weather.source != 'live' ||
        (_assessment != null && dataSource(_assessment) != 'live'),
    onRetry: _load,
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) {
    final weather = _conditions?.weather;
    final impact = _conditions?.analysis;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        title: Text('Hive environment', style: _text(18, FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Refresh hive environment',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SourceDot(source: widget.apiary.source),
                    const SizedBox(height: 8),
                    if (weather != null) SourceDot(source: weather.source),
                    if (impact != null) SourceDot(source: impact.source),
                    if (_assessment != null)
                      SourceDot(source: dataSource(_assessment)),
                    _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.hive_outlined,
                                color: AppColors.accent3,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.apiary.locationName,
                                  style: _text(
                                    12,
                                    FontWeight.w700,
                                    AppColors.accent3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.hive.name,
                            style: _text(30, FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.hive.hiveType} ? ${widget.hive.numFrames} frames',
                            style: _text(
                              14,
                              FontWeight.w500,
                              AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            widget.hive.beeSpecies,
                            style: _text(
                              13,
                              FontWeight.w400,
                              AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.apiary.areaAddress,
                            style: _text(13, FontWeight.w400),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Saved hive status: ${widget.hive.status}',
                            style: _text(12, FontWeight.w600),
                          ),
                          Text(
                            'Status is a saved record, not a live health assessment.',
                            style: _text(
                              11,
                              FontWeight.w400,
                              AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: LinearProgressIndicator(),
                      ),
                    _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OUTSIDE THE HIVE',
                            style: _text(
                              11,
                              FontWeight.w700,
                              AppColors.accent3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (weather != null) ...[
                            Text(
                              '${weather.temperatureC.toStringAsFixed(1)} \u00b0C',
                              style: _text(40, FontWeight.w800),
                            ),
                            Text(
                              weather.condition,
                              style: _text(16, FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                Chip(
                                  avatar: const Icon(
                                    Icons.water_drop_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    '${weather.humidityPercent}% humidity',
                                  ),
                                ),
                                Chip(
                                  avatar: const Icon(
                                    Icons.air_rounded,
                                    size: 18,
                                  ),
                                  label: Text('${weather.windKph} km/h wind'),
                                ),
                                Chip(
                                  avatar: const Icon(
                                    Icons.umbrella_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    '${weather.precipitationMm} mm rain',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${weather.locationName} ? WeatherAPI ? ${weather.updatedAt}',
                              style: _text(
                                11,
                                FontWeight.w500,
                                AppColors.textSecondary,
                              ),
                            ),
                          ] else
                            Text(
                              _weatherError ?? 'Loading local observations?',
                              style: _text(14, FontWeight.w500),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Weather describes the apiary surroundings. It does not measure temperature or humidity inside this hive.',
                            style: _text(
                              12,
                              FontWeight.w400,
                              AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      color: AppColors.badgeLeafBg,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Season & surroundings',
                      style: _text(21, FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (impact != null) ...[
                            Text(
                              impact.season,
                              style: _text(
                                20,
                                FontWeight.w700,
                                AppColors.accent3,
                              ),
                            ),
                            Text(
                              impact.seasonPeriod,
                              style: _text(
                                12,
                                FontWeight.w500,
                                AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              impact.environmentalSummary,
                              style: _text(14, FontWeight.w400),
                            ),
                            const SizedBox(height: 12),
                            for (final tip in impact.recommendations)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.eco_outlined,
                                      size: 18,
                                      color: AppColors.accent3,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        tip,
                                        style: _text(13, FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              'Preliminary environmental guidance from available weather. Confirm conditions at the hive.',
                              style: _text(
                                11,
                                FontWeight.w400,
                                AppColors.textSecondary,
                              ),
                            ),
                          ] else
                            Text(
                              _weatherError ?? 'Seasonal context is loading?',
                              style: _text(13, FontWeight.w400),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _saving ? null : _saveSnapshot,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.bookmark_add_outlined),
                          label: Text(_saving ? 'Saving...' : 'Save snapshot'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  IT23183186EnvironmentHistoryScreen(
                                    hiveId: widget.hive.id,
                                    hiveName: widget.hive.name,
                                    api: widget.assessmentApi,
                                  ),
                            ),
                          ),
                          icon: const Icon(Icons.history_rounded),
                          label: const Text('Saved history'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _saveStatus ?? 'Save a fresh weather and assessment snapshot for this hive. Missing readings remain marked unavailable.',
                      style: _text(
                        12,
                        FontWeight.w400,
                        AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => IT23183186ColonyWorkspaceScreen(
                            hive: widget.hive,
                            apiary: widget.apiary,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.dashboard_customize_outlined),
                      label: const Text('Open colony workspace'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Colony observations',
                      style: _text(21, FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    if (_assessment != null)
                      ColonyAssessmentCard(assessment: _assessment!)
                    else
                      _card(
                        Text(
                          _assessmentError ??
                              'Checking observations for this hive?',
                          style: _text(13, FontWeight.w400),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ImageModelAnalysisScreen(
                            location: _location,
                            hiveId: widget.hive.id,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Check a bee or frame photo'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
