import 'package:flutter/material.dart';

import '../widgets/environment_source.dart';

import '../services/weather_service.dart';
import '../utils/theme.dart';
import '../widgets/IT23183186_weather_dashboard.dart';

class IT23183186EnvironmentDetailsScreen extends StatefulWidget {
  final String locationQuery;
  final WeatherService weatherService;
  const IT23183186EnvironmentDetailsScreen({
    super.key,
    required this.locationQuery,
    this.weatherService = const WeatherService(),
  });

  @override
  State<IT23183186EnvironmentDetailsScreen> createState() => _DetailsState();
}

class _DetailsState extends State<IT23183186EnvironmentDetailsScreen> {
  CurrentWeather? _weather;
  WeatherForecast? _forecast;
  List<HistoricalWeatherDay> _history = const [];
  bool _loading = true;
  String? _error, _forecastError, _historyError;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _weather = null;
      _forecast = null;
      _history = const [];
      _error = _forecastError = _historyError = null;
    });
    await Future.wait([
      () async {
        try {
          final value = await widget.weatherService.fetchCurrent(
            widget.locationQuery,
          );
          if (mounted && request == _request) {
            setState(() => _weather = value);
          }
        } catch (_) {
          if (mounted && request == _request) {
            setState(
              () => _error = 'Weather details unavailable. Please retry.',
            );
          }
        }
      }(),
      () async {
        try {
          final value = await widget.weatherService.fetchForecast(
            widget.locationQuery,
          );
          if (mounted && request == _request) {
            setState(() => _forecast = value);
          }
        } catch (_) {
          if (mounted && request == _request) {
            setState(
              () => _forecastError = 'Forecast unavailable. Please retry.',
            );
          }
        }
      }(),
      () async {
        try {
          final value = await widget.weatherService.fetchHistoryAnalysis(
            widget.locationQuery,
          );
          if (mounted && request == _request) {
            setState(() => _history = value.days);
          }
        } catch (_) {
          if (mounted && request == _request) {
            setState(
              () =>
                  _historyError = 'Weather history unavailable. Please retry.',
            );
          }
        }
      }(),
    ]);
    if (mounted && request == _request) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => EnvironmentRecovery(
    needed: () =>
        _weather?.source != 'live' ||
        _forecast?.source != 'live' ||
        (_history.isNotEmpty && _history.first.source != 'live'),
    onRetry: _reload,
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    appBar: AppBar(
      title: const Text('Environment details'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _reload,
          tooltip: 'Refresh weather details',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _reload,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: EnvironmentWeatherDashboard(
                showSummary: false,
                locationQuery: widget.locationQuery,
                weather: _weather,
                forecast: _forecast,
                history: _history,
                loading: _loading,
                loadingForecast: _loading,
                loadingHistory: _loading,
                error: _error,
                forecastError: _forecastError,
                historyError: _historyError,
                onRetry: _reload,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
