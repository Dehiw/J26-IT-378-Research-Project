import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/weather_service.dart';
import '../utils/theme.dart';
import 'environment_source.dart';
import 'IT23183186_apiary_map.dart';

/// Reference-inspired weather components using actual observations and forecasts.
class EnvironmentWeatherDashboard extends StatefulWidget {
  final CurrentWeather? weather;
  final WeatherForecast? forecast;
  final List<HistoricalWeatherDay> history;
  final bool loading, loadingForecast, loadingHistory;
  final String? error, forecastError, historyError;
  final String locationQuery;
  final VoidCallback onRetry;
  final bool showSummary, showDetails;
  const EnvironmentWeatherDashboard({
    super.key,
    this.showSummary = true,
    this.showDetails = true,
    this.weather,
    this.forecast,
    this.history = const [],
    this.loading = false,
    this.loadingForecast = false,
    this.loadingHistory = false,
    this.error,
    this.forecastError,
    this.historyError,
    required this.locationQuery,
    required this.onRetry,
  });
  @override
  State<EnvironmentWeatherDashboard> createState() => _WeatherDashboardState();
}

class _WeatherDashboardState extends State<EnvironmentWeatherDashboard> {
  int _day = 0, _hourMetric = 0, _trendMetric = 0, _period = 7;
  bool _list = false, _feelsLike = false;
  int? _month;
  static const _metrics = ['Temperature', 'Precipitation', 'Humidity', 'Wind'];
  static const _units = ['°C', 'mm', '%', 'km/h'];
  TextStyle _style(
    double size, [
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.textPrimary,
  ]) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.4,
  );
  Widget _title(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: _style(22, FontWeight.w800))),
            SourceDot(
              source: title.toLowerCase().contains('forecast')
                  ? widget.forecast?.source ?? 'unavailable'
                  : title == 'Weather overview' ||
                        title == 'Monthly calendar' ||
                        title.toLowerCase().contains('histor') ||
                        title.toLowerCase().contains('trend')
                  ? (widget.history.isEmpty
                        ? 'unavailable'
                        : widget.history.first.source)
                  : widget.weather?.source ?? 'unavailable',
              compact: true,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: _style(12, FontWeight.w400, AppColors.textSecondary),
        ),
      ],
    ),
  );
  Widget _panel(Widget child, {Color color = AppColors.bgCard}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
  double? _number(dynamic n) => n is num && n.isFinite ? n.toDouble() : null;
  String _value(num? n, [String unit = '']) => n == null
      ? 'Unavailable'
      : '${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1)}${unit.isEmpty ? '' : ' $unit'}';
  DateTime get _anchor =>
      DateTime.tryParse(
        widget.forecast?.localtime ?? widget.weather?.updatedAt ?? '',
      ) ??
      DateTime.now();
  List<Map<String, dynamic>> get _days => widget.forecast?.days ?? [];
  IconData _icon(String text) {
    final s = text.toLowerCase();
    if (s.contains('thunder')) return Icons.thunderstorm_outlined;
    if (s.contains('rain') || s.contains('drizzle')) {
      return Icons.water_drop_outlined;
    }
    if (s.contains('cloud') || s.contains('overcast')) {
      return Icons.cloud_outlined;
    }
    return Icons.wb_sunny_outlined;
  }

  @override
  void didUpdateWidget(covariant EnvironmentWeatherDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locationQuery != widget.locationQuery) {
      _day = 0;
      _month = null;
    }
    if (_day >= _days.length) _day = 0;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.showSummary) ...[
        _title(
          'Weather at your apiary',
          'Outdoor conditions for the selected location. WeatherAPI observations and forecasts.',
        ),
        LayoutBuilder(
          builder: (context, box) {
            final weather = _current();
            final map = _map();
            return box.maxWidth >= 900
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: weather),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: map),
                    ],
                  )
                : Column(children: [weather, const SizedBox(height: 16), map]);
          },
        ),
      ],
      if (widget.showDetails) ...[
        const SizedBox(height: 28),
        _forecast(),
        const SizedBox(height: 28),
        _title(
          'Weather details',
          'Current outdoor measurements. Missing fields are not estimated.',
        ),
        _details(),
        const SizedBox(height: 28),
        _calendar(),
        const SizedBox(height: 20),
        _overview(),
        const SizedBox(height: 28),
        _trends(),
      ],
    ],
  );

  Widget _current() {
    final w = widget.weather;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CURRENT WEATHER',
                  style: _style(11, FontWeight.w700, AppColors.accent3),
                ),
              ),
              SourceDot(source: w?.source ?? 'unavailable'),
              const SizedBox(width: 8),
              const Icon(
                Icons.sensors_rounded,
                color: AppColors.accent3,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            w?.updatedAt ?? 'Observation time unavailable',
            style: _style(12, FontWeight.w400, AppColors.textSecondary),
          ),
          const SizedBox(height: 22),
          if (widget.loading)
            const LinearProgressIndicator()
          else if (w == null) ...[
            Text('Weather is unavailable', style: _style(24, FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              widget.error ?? 'Check your connection and retry.',
              style: _style(13),
            ),
            TextButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry weather'),
            ),
          ] else ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 10,
              children: [
                Icon(_icon(w.condition), size: 68, color: AppColors.accent),
                Text(
                  '${w.temperatureC.toStringAsFixed(1)}°',
                  style: _style(64, FontWeight.w800),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.condition, style: _style(20, FontWeight.w700)),
                    Text(
                      'Feels like ${w.feelsLikeC.toStringAsFixed(1)} °C',
                      style: _style(14, FontWeight.w400),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${w.locationName}${w.region == null ? '' : ', ${w.region}'}',
              style: _style(15, FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 26,
              runSpacing: 18,
              children: [
                _quick('Wind', '${w.windKph} km/h ${w.windDirection}'),
                _quick('Humidity', '${w.humidityPercent}%'),
                _quick('Visibility', _value(w.visibilityKm, 'km')),
                _quick('Pressure', _value(w.pressureMb, 'hPa')),
                _quick('Dew point', _value(w.dewPointC, '°C')),
                _quick('Precipitation', '${w.precipitationMm} mm'),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Outside the hive | Celsius / metric | WeatherAPI',
            style: _style(11, FontWeight.w500, AppColors.textSecondary),
          ),
        ],
      ),
      color: AppColors.badgeLeafBg,
    );
  }

  Widget _quick(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: _style(11, FontWeight.w400, AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text(value, style: _style(14, FontWeight.w700)),
    ],
  );
  Widget _map() {
    final coords = widget.locationQuery
        .split(',')
        .map((s) => double.tryParse(s.trim()))
        .toList();
    final lat =
        widget.weather?.latitude ?? (coords.length == 2 ? coords[0] : null);
    final lon =
        widget.weather?.longitude ?? (coords.length == 2 ? coords[1] : null);
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      return _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.map_outlined, color: AppColors.accent3, size: 40),
            const SizedBox(height: 16),
            Text('Apiary map', style: _style(20, FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Save GPS coordinates for this apiary or load local weather to resolve its map location.',
              style: _style(13),
            ),
          ],
        ),
      );
    }
    return ApiaryWeatherMap(
      latitude: lat,
      longitude: lon,
      locationName: widget.weather?.locationName ?? widget.locationQuery,
      weatherLabel: widget.weather == null
          ? null
          : '${widget.weather!.temperatureC}°C | ${widget.weather!.condition}',
    );
  }

  Widget _metricChips(int value, ValueChanged<int> onChanged) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            _metrics.length,
            (i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_metrics[i]),
                selected: value == i,
                selectedColor: AppColors.accent,
                onSelected: (_) => onChanged(i),
              ),
            ),
          ),
        ),
      );
  Widget _forecast() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          'Daily & hourly forecast',
          'Forecast availability follows your weather provider plan.',
        ),
        if (widget.loadingForecast)
          const LinearProgressIndicator()
        else if (_days.isEmpty)
          Text(
            widget.forecastError ?? 'No forecast data is available.',
            style: _style(13),
          )
        else ...[
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final item = _days[i];
                final data = item['day'] as Map? ?? {};
                final date = DateTime.tryParse(item['date']?.toString() ?? '');
                final condition =
                    (data['condition'] as Map?)?['text']?.toString() ?? '';
                return SizedBox(
                  width: 154,
                  child: Material(
                    color: _day == i ? AppColors.bgElevated : AppColors.bgCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: _day == i ? AppColors.accent : AppColors.border,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => _day = i),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              date == null
                                  ? 'Date unavailable'
                                  : DateFormat('EEE, d MMM').format(date),
                              style: _style(12, FontWeight.w700),
                            ),
                            const Spacer(),
                            Icon(
                              _icon(condition),
                              size: 32,
                              color: AppColors.hiveLow,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_value(_number(data['maxtemp_c']))}° / ${_value(_number(data['mintemp_c']))}°',
                              style: _style(17, FontWeight.w800),
                            ),
                            Text(
                              'Rain ${_value(_number(data['daily_chance_of_rain']), '%')}',
                              style: _style(11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _metricChips(_hourMetric, (i) => setState(() => _hourMetric = i)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _list = !_list),
                icon: Icon(_list ? Icons.show_chart : Icons.list),
                label: Text(_list ? 'Show chart' : 'Show list'),
              ),
              if (_hourMetric == 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: _feelsLike,
                      onChanged: (v) => setState(() => _feelsLike = v),
                    ),
                    Text('Feels like', style: _style(12)),
                  ],
                ),
            ],
          ),
          _hourly(),
        ],
      ],
    ),
  );
  Widget _hourly() {
    final hours = (_days[_day]['hour'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final key = [
      '${_feelsLike ? 'feelslike' : 'temp'}_c',
      'precip_mm',
      'humidity',
      'wind_kph',
    ][_hourMetric];
    final values = <FlSpot>[];
    final labels = <String>[];
    final conditions = <String>[];
    for (var i = 0; i < hours.length; i++) {
      final n = _number(hours[i][key]);
      if (n == null) continue;
      final date = DateTime.tryParse(hours[i]['time']?.toString() ?? '');
      values.add(FlSpot(values.length.toDouble(), n));
      conditions.add(
        (hours[i]['condition'] as Map?)?['text']?.toString() ?? '',
      );
      labels.add(date == null ? '$i' : DateFormat('HH:mm').format(date));
    }
    if (values.isEmpty) {
      return Text('Hourly values are unavailable.', style: _style(13));
    }
    if (_list) {
      return SizedBox(
        height: 160,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(
            width: 90,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(labels[i], style: _style(12)),
                const SizedBox(height: 14),
                Icon(_icon(conditions[i]), color: AppColors.hiveLow),
                const SizedBox(height: 14),
                Text(
                  _value(values[i].y, _units[_hourMetric]),
                  style: _style(13, FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _chart(
      [values],
      labels,
      [_hourMetric == 1 ? AppColors.blue : AppColors.accent3],
      _units[_hourMetric],
    );
  }

  Widget _chart(
    List<List<FlSpot>> series,
    List<String> labels,
    List<Color> colors,
    String unit,
  ) {
    if (series.every((s) => s.isEmpty)) {
      return Text('No observations available.', style: _style(13));
    }
    final values = series.expand((s) => s).map((p) => p.y).toList();
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final pad = math.max((high - low) * .15, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            unit,
            style: _style(11, FontWeight.w600, AppColors.textSecondary),
          ),
        ),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: low - pad,
              maxY: high + pad,
              minX: 0,
              maxX: math.max(1, labels.length - 1).toDouble(),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.border, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (v, _) =>
                        Text(v.toStringAsFixed(0), style: _style(10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: math
                        .max(1, (labels.length / 4).ceil())
                        .toDouble(),
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        v.toInt() >= 0 && v.toInt() < labels.length
                            ? labels[v.toInt()]
                            : '',
                        style: _style(9),
                      ),
                    ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map(
                        (spot) => LineTooltipItem(
                          '${labels[spot.x.toInt()]}\n${spot.y.toStringAsFixed(1)} $unit',
                          _style(12, FontWeight.w600, AppColors.bgCard),
                        ),
                      )
                      .toList(),
                ),
              ),
              lineBarsData: List.generate(
                series.length,
                (i) => LineChartBarData(
                  spots: series[i],
                  color: colors[i],
                  barWidth: 2.5,
                  isCurved: false,
                  dotData: FlDotData(show: series[i].length < 3),
                  belowBarData: BarAreaData(
                    show: true,
                    color: colors[i].withValues(alpha: .08),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _details() {
    final w = widget.weather;
    final aq = _number(w?.airQuality?['us-epa-index']);
    final aqNames = [
      'Good',
      'Moderate',
      'Unhealthy for sensitive groups',
      'Unhealthy',
      'Very unhealthy',
      'Hazardous',
    ];
    final data = <(String, String, String, IconData, double?, Color)>[
      (
        'Temperature',
        _value(w?.temperatureC, '°C'),
        'Outdoor air temperature',
        Icons.thermostat_outlined,
        null,
        AppColors.accent2,
      ),
      (
        'Feels like',
        _value(w?.feelsLikeC, '°C'),
        'Apparent outdoor temperature',
        Icons.wb_sunny_outlined,
        null,
        AppColors.hiveLow,
      ),
      (
        'Cloud cover',
        _value(w?.cloudPercent, '%'),
        w?.condition ?? 'Sky observation unavailable',
        Icons.cloud_outlined,
        w?.cloudPercent == null ? null : w!.cloudPercent! / 100,
        AppColors.blue,
      ),
      (
        'Precipitation',
        _value(w?.precipitationMm, 'mm'),
        'Current observation, not a daily total',
        Icons.water_drop_outlined,
        null,
        AppColors.blue,
      ),
      (
        'Wind',
        _value(w?.windKph, 'km/h'),
        '${w?.windDirection ?? ''} | Gust ${_value(w?.gustKph, 'km/h')}',
        Icons.navigation_outlined,
        null,
        AppColors.accent3,
      ),
      (
        'Humidity',
        w == null ? 'Unavailable' : '${w.humidityPercent}%',
        'Outdoor relative humidity',
        Icons.water_outlined,
        w == null ? null : w.humidityPercent / 100,
        AppColors.blue,
      ),
      (
        'UV index',
        _value(w?.uvIndex),
        'Provider ultraviolet index',
        Icons.wb_sunny_outlined,
        w == null ? null : (w.uvIndex / 11).clamp(0, 1),
        AppColors.warning,
      ),
      (
        'Air quality',
        aq != null && aq >= 1 && aq <= 6
            ? aqNames[aq.toInt() - 1]
            : 'Unavailable',
        'US EPA category (1-6), not numeric AQI',
        Icons.air_rounded,
        aq == null ? null : (aq / 6).clamp(0, 1),
        AppColors.accent3,
      ),
      (
        'Visibility',
        _value(w?.visibilityKm, 'km'),
        'Horizontal visibility outdoors',
        Icons.visibility_outlined,
        null,
        AppColors.accent3,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 900
            ? 3
            : box.maxWidth >= 560
            ? 2
            : 1;
        final width = (box.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: data
              .map(
                (d) => SizedBox(
                  width: width,
                  child: _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                d.$1,
                                style: _style(14, FontWeight.w600),
                              ),
                            ),
                            Icon(d.$4, color: d.$6),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 100,
                          child: _graphic(d.$1, d.$4, d.$5, d.$6),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          d.$2,
                          style: _style(
                            d.$2.length > 14 ? 21 : 30,
                            FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (d.$5 != null) ...[
                          LinearProgressIndicator(
                            value: d.$5!.clamp(0, 1),
                            color: d.$6,
                            backgroundColor: AppColors.bgElevated,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Text(
                          d.$3,
                          style: _style(
                            11,
                            FontWeight.w400,
                            AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _graphic(String label, IconData icon, double? fraction, Color color) {
    if (label == 'Temperature' || label == 'Feels like') {
      final key = label == 'Temperature' ? 'temp_c' : 'feelslike_c';
      final hours = _days.isEmpty
          ? <dynamic>[]
          : (_days.first['hour'] as List? ?? []);
      final values = hours
          .whereType<Map>()
          .map((h) => _number(h[key]))
          .whereType<double>()
          .toList();
      if (values.length > 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CustomPaint(painter: _WeatherSparkline(values, color)),
            ),
            Text(
              'Hourly forecast trend',
              style: _style(10, FontWeight.w400, AppColors.textSecondary),
            ),
          ],
        );
      }
    }
    if (label == 'Wind' && widget.weather?.windDegree != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 5),
                ),
              ),
              const Positioned(top: 0, child: Text('N')),
              const Positioned(bottom: 0, child: Text('S')),
              const Positioned(left: 0, child: Text('W')),
              const Positioned(right: 0, child: Text('E')),
              Transform.rotate(
                angle: widget.weather!.windDegree! * math.pi / 180,
                child: Icon(Icons.north_rounded, color: color, size: 42),
              ),
            ],
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (fraction != null)
              SizedBox(
                width: 82,
                height: 82,
                child: CircularProgressIndicator(
                  value: fraction.clamp(0, 1),
                  strokeWidth: 7,
                  color: color,
                  backgroundColor: AppColors.bgElevated,
                ),
              ),
            Icon(
              icon,
              size: fraction == null ? 58 : 36,
              color: color.withValues(alpha: widget.weather == null ? .3 : 1),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, Map<String, dynamic>> get _calendarData {
    final result = <String, Map<String, dynamic>>{};
    for (final h in widget.history) {
      result[h.date] = {
        'high': h.maximumTemperatureC,
        'low': h.minimumTemperatureC,
        'rain': h.precipitationMm,
        'kind': 'Observed',
      };
    }
    for (final f in _days) {
      final d = f['day'] as Map? ?? {};
      result[f['date'].toString()] = {
        'high': d['maxtemp_c'],
        'low': d['mintemp_c'],
        'rain': d['totalprecip_mm'],
        'kind': 'Forecast',
        'condition': (d['condition'] as Map?)?['text'],
      };
    }
    return result;
  }

  Widget _calendar() {
    final year = _anchor.year;
    final month = _month ?? _anchor.month;
    final start = DateTime(year, month);
    final offset = start.weekday % 7;
    final count = DateTime(year, month + 1, 0).day;
    final data = _calendarData;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(
            'Monthly calendar',
            'Observed history and available forecasts. Blank dates have no loaded data.',
          ),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              SourceDot(
                source: widget.history.isEmpty
                    ? 'unavailable'
                    : widget.history.first.source,
              ),
              const Text('observations'),
              SourceDot(source: widget.forecast?.source ?? 'unavailable'),
              const Text('forecast'),
            ],
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 12,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(DateFormat('MMM').format(DateTime(year, i + 1))),
                selected: month == i + 1,
                selectedColor: AppColors.accent,
                onSelected: (_) => setState(() => _month = i + 1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            DateFormat('MMMM yyyy').format(start),
            style: _style(16, FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                .map(
                  (s) => Expanded(
                    child: Center(
                      child: Text(s, style: _style(11, FontWeight.w600)),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, box) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ((count + offset) / 7).ceil() * 7,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                mainAxisExtent: box.maxWidth < 420 ? 100 : 110,
              ),
              itemBuilder: (_, i) {
                final day = i - offset + 1;
                if (day < 1 || day > count) return const SizedBox.shrink();
                final date = DateTime(year, month, day);
                final key = DateFormat('yyyy-MM-dd').format(date);
                final entry = data[key];
                final today =
                    year == _anchor.year &&
                    month == _anchor.month &&
                    day == _anchor.day;
                return Material(
                  color: today ? AppColors.bgElevated : AppColors.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: today ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(DateFormat('d MMM yyyy').format(date)),
                        content: Text(
                          entry == null
                              ? 'No weather data loaded for this date.'
                              : '${entry['kind']}\nHigh ${_value(_number(entry['high']), '°C')}\nLow ${_value(_number(entry['low']), '°C')}\nPrecipitation ${_value(_number(entry['rain']), 'mm')}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: _style(
                              11,
                              today ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                          if (entry != null) ...[
                            const SizedBox(height: 4),
                            Icon(
                              _number(entry['rain']) != null &&
                                      _number(entry['rain'])! > 0
                                  ? Icons.water_drop_outlined
                                  : Icons.cloud_outlined,
                              size: 16,
                              color: entry['kind'] == 'Forecast'
                                  ? AppColors.hiveLow
                                  : AppColors.blue,
                            ),
                            FittedBox(
                              child: Text(
                                '${_value(_number(entry['high']))}°',
                                style: _style(11, FontWeight.w700),
                              ),
                            ),
                          ] else
                            Text(
                              '--',
                              style: _style(
                                10,
                                FontWeight.w400,
                                AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Blue: observations | Gold: forecasts | All values in °C',
            style: _style(11, FontWeight.w400, AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  List<HistoricalWeatherDay> get _monthHistory => widget.history.where((h) {
    final date = DateTime.tryParse(h.date);
    return date?.year == _anchor.year &&
        date?.month == (_month ?? _anchor.month);
  }).toList();
  Widget _overview() {
    final days = _monthHistory;
    final wet = days.where((d) => d.precipitationMm > 0).length;
    final dry = days.length - wet;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(
            'Weather overview',
            'Summary of ${days.length} loaded observation days in the selected month; forecasts excluded.',
          ),
          if (days.isEmpty)
            Text('No observations loaded for this month.', style: _style(13))
          else
            Wrap(
              spacing: 28,
              runSpacing: 20,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          centerSpaceRadius: 52,
                          sectionsSpace: 2,
                          sections: [
                            if (dry > 0)
                              PieChartSectionData(
                                value: dry.toDouble(),
                                color: AppColors.accent,
                                radius: 20,
                                showTitle: false,
                              ),
                            if (wet > 0)
                              PieChartSectionData(
                                value: wet.toDouble(),
                                color: AppColors.blue,
                                radius: 20,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(
                          DateTime(_anchor.year, _month ?? _anchor.month),
                        ),
                        style: _style(24, FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                _quick('Days without recorded rain', '$dry'),
                _quick('Days with recorded rain', '$wet'),
                _quick(
                  'Average observed high',
                  _value(
                    days
                            .map((d) => d.maximumTemperatureC)
                            .reduce((a, b) => a + b) /
                        days.length,
                    '°C',
                  ),
                ),
                _quick(
                  'Average observed low',
                  _value(
                    days
                            .map((d) => d.minimumTemperatureC)
                            .reduce((a, b) => a + b) /
                        days.length,
                    '°C',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _trends() {
    final records = [...widget.history]
      ..sort((a, b) => a.date.compareTo(b.date));
    final days = records.length > _period
        ? records.sublist(records.length - _period)
        : records;
    final labels = days
        .map((d) => DateFormat('d MMM').format(DateTime.parse(d.date)))
        .toList();
    List<FlSpot> series(double? Function(HistoricalWeatherDay) read) => [
      for (var i = 0; i < days.length; i++)
        if (read(days[i]) != null) FlSpot(i.toDouble(), read(days[i])!),
    ];
    final plots = _trendMetric == 0
        ? [
            series((d) => d.maximumTemperatureC),
            series((d) => d.minimumTemperatureC),
          ]
        : [
            series(
              (d) => _trendMetric == 1
                  ? d.precipitationMm
                  : _trendMetric == 2
                  ? d.averageHumidityPercent
                  : d.maximumWindKph,
            ),
          ];
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(
            'Weather trends',
            'Daily observations from the available history window.',
          ),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: _period,
            decoration: const InputDecoration(labelText: 'History period'),
            items: const [
              DropdownMenuItem(value: 3, child: Text('Last 3 loaded days')),
              DropdownMenuItem(value: 7, child: Text('Last 7 loaded days')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _period = v);
            },
          ),
          const SizedBox(height: 16),
          _metricChips(_trendMetric, (v) => setState(() => _trendMetric = v)),
          const SizedBox(height: 20),
          if (widget.loadingHistory)
            const LinearProgressIndicator()
          else if (days.isEmpty)
            Text(
              widget.historyError ?? 'Historical weather is unavailable.',
              style: _style(13),
            )
          else ...[
            _chart(plots, labels, [
              AppColors.accent2,
              AppColors.blue,
            ], _units[_trendMetric]),
            if (_trendMetric == 0)
              Text(
                'Terracotta: daily high | Blue: daily low',
                style: _style(11, FontWeight.w400, AppColors.textSecondary),
              ),
          ],
        ],
      ),
    );
  }
}

/// Sparkline uses only actual hourly forecast values, without synthetic smoothing.
class _WeatherSparkline extends CustomPainter {
  final List<double> values;
  final Color color;
  _WeatherSparkline(this.values, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final span = math.max(high - low, 1);
    final points = List.generate(
      values.length,
      (i) => Offset(
        8 + i / (values.length - 1) * (size.width - 16),
        size.height * .75 - (values[i] - low) / span * size.height * .48,
      ),
    );
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height * .94)
      ..lineTo(points.first.dx, size.height * .94)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: .1));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(points.last, 7, Paint()..color = AppColors.bgCard);
    canvas.drawCircle(points.last, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WeatherSparkline oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
