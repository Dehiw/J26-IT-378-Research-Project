import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/environment_source.dart';

import 'package:fl_chart/fl_chart.dart';

import '../models/apiary_model.dart';
import '../services/IT23183186_workspace_api.dart';
import '../services/environment_fallback.dart';
import '../utils/theme.dart';
import '../widgets/IT23183186_colony_ui.dart';
import '../widgets/IT23183186_assessment_card.dart';
import 'IT23183186_colony_observation_screen.dart';
import 'IT23183186_care_plan_screen.dart';
import 'image_model_analysis_screen.dart';

class IT23183186ColonyWorkspaceScreen extends StatefulWidget {
  final HiveModel hive;
  final ApiaryModel apiary;
  final ColonyWorkspaceApi api;
  final String initialTab;
  const IT23183186ColonyWorkspaceScreen({
    super.key,
    required this.hive,
    required this.apiary,
    this.api = const ColonyWorkspaceApi(),
    this.initialTab = 'Overview',
  });
  @override
  State<IT23183186ColonyWorkspaceScreen> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<IT23183186ColonyWorkspaceScreen>
    with WidgetsBindingObserver {
  static const _tabs = [
    'Overview',
    'Observations',
    'Trends',
    'Alerts',
    'Care',
    'Images',
    'Settings',
  ];
  Map<String, dynamic> _data = {};
  late String _tab;
  bool _loading = false, _busy = false, _onlyUnread = true, _active = true;
  String? _error, _message;
  String _metric = 'temperature';
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
  }

  List<Map<String, dynamic>> _items(String key) => (_data[key] as List? ?? [])
      .whereType<Map>()
      .map((v) => Map<String, dynamic>.from(v))
      .toList();
  Map get _monitoring => _data['monitoring'] as Map? ?? {};
  Map get _assessment => _monitoring['assessment'] as Map? ?? {};
  Map get _preferences =>
      _data['preferences'] as Map? ??
      {'auto_refresh': true, 'refresh_seconds': 300, 'in_app_alerts': true};
  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.load(widget.hive.id);
      if (!mounted) return;
      setState(() => _data = data);
      _timer?.cancel();
      if (_preferences['auto_refresh'] == true) {
        _timer = Timer.periodic(
          Duration(
            seconds: (_preferences['refresh_seconds'] as num?)?.toInt() ?? 300,
          ),
          (_) {
            if (mounted &&
                _active &&
                !_loading &&
                !_busy &&
                ModalRoute.of(context)?.isCurrent == true) {
              _load();
            }
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Colony records could not be loaded. Check your connection and sign-in, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mutate(
    Future<dynamic> Function() action,
    String message,
  ) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      setState(
        () => _message = result is Map && result['local_only'] == true
            ? 'Demo change saved on this device only.'
            : message,
      );
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Change was not saved. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _observation() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => IT23183186ColonyObservationScreen(
          hive: widget.hive,
          api: widget.api,
        ),
      ),
    );
    if (mounted && saved == true) {
      setState(() {
        _tab = 'Observations';
        _message = 'Observation saved. Demo changes stay on this device.';
      });
      await _load();
    }
  }

  Future<void> _carePlan() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            IT23183186CarePlanScreen(hive: widget.hive, api: widget.api),
      ),
    );
    if (mounted && saved == true) {
      setState(() {
        _tab = 'Care';
        _message = 'Care plan saved. Demo changes stay on this device.';
      });
      await _load();
    }
  }

  String _label(dynamic v) =>
      (v?.toString() ?? 'Unavailable').replaceAll('_', ' ');
  Widget _line(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text('$label: ${_label(value)}', style: colonyText(13)),
  );
  Widget _empty(String text) => ColonyNotice(text);
  Widget _actions() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      FilledButton.icon(
        onPressed: _busy ? null : _observation,
        icon: const Icon(Icons.add_task),
        label: const Text('Record observations'),
      ),
      OutlinedButton.icon(
        onPressed: _busy ? null : _carePlan,
        icon: const Icon(Icons.event_note_outlined),
        label: const Text('Plan hive care'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => EnvironmentRecovery(
    needed: () =>
        dataSource(_data) != 'live' ||
        (_monitoring['sensor'] is Map &&
            dataSource(_monitoring['sensor'] as Map) != 'live'),
    onRetry: _load,
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    appBar: AppBar(
      backgroundColor: AppColors.bgPrimary,
      title: const Text('Colony workspace'),
      actions: [
        IconButton(
          tooltip: 'Refresh colony workspace',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.apiary.locationName,
                      style: colonyText(12, FontWeight.w700, AppColors.accent3),
                    ),
                    Text(
                      widget.hive.name,
                      style: colonyText(28, FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Observe. Understand. Plan the next visit.',
                      style: colonyText(
                        14,
                        FontWeight.w400,
                        AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _actions(),
                    const SizedBox(height: 18),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _tabs
                            .map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(t),
                                  selected: _tab == t,
                                  selectedColor: AppColors.accent,
                                  onSelected: (_) => setState(() => _tab = t),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_loading || _busy) const LinearProgressIndicator(),
                    if (_error != null) ...[
                      ColonyNotice(_error!, error: true),
                      TextButton(
                        onPressed: _loading ? null : _load,
                        child: const Text('Retry'),
                      ),
                    ],
                    SourceDot(source: dataSource(_data)),
                    if (dataSource(_data) == 'demo')
                      const ColonyNotice(
                        'Demo workspace. Changes are saved on this device only.',
                      ),
                    if (_message != null) ColonyNotice(_message!),
                    if (_tab == 'Overview') ..._overview(),
                    if (_tab == 'Observations') ..._observations(),
                    if (_tab == 'Trends') ..._trends(),
                    if (_tab == 'Alerts') ..._alerts(),
                    if (_tab == 'Care') ..._care(),
                    if (_tab == 'Images') ..._images(),
                    if (_tab == 'Settings') ..._settings(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  List<Widget> _overview() {
    final models = _data['models'] as Map? ?? {};
    final observation = _items('observations').firstOrNull;
    final sensor = _monitoring['sensor'] as Map?;
    return [
      if (sensor != null) SourceDot(source: dataSource(sensor)),
      ColonySection(
        source: dataSource(_data),
        title: 'Colony evidence',
        subtitle: 'Source availability is kept separate from colony health.',
        icon: Icons.shield_outlined,
        children: [
          if (_preferences['in_app_alerts'] != true && _data.isNotEmpty)
            _empty(
              'Alert summaries are paused. Open Alerts to review the evidence.',
            )
          else if (_assessment.isNotEmpty)
            ColonyAssessmentCard(
              assessment: Map<String, dynamic>.from(_assessment),
              compact: true,
            )
          else
            _empty(
              _loading
                  ? 'Loading available evidence...'
                  : 'Assessment is unavailable.',
            ),
          const SizedBox(height: 12),
          _line('Outdoor weather', _assessment['evidence']?['weather']),
          _line('Hive sensors', _assessment['evidence']?['sensors']),
          _line(
            'Model A',
            (models['model_a'] as Map?)?['available'] == true
                ? 'ready'
                : 'unavailable',
          ),
          _line(
            'Model B',
            (models['model_b'] as Map?)?['available'] == true
                ? 'ready for structural detection'
                : 'unavailable',
          ),
          const ColonyNotice(
            'Monitoring guidance is preliminary, not a disease diagnosis.',
          ),
        ],
      ),
      ColonySection(
        source: sensor == null ? 'unavailable' : dataSource(sensor),
        title: 'Inside this hive',
        icon: Icons.sensors_outlined,
        children: [
          if (sensor == null)
            _empty(
              'No sensor reading available. Connect the IoT feed for this hive.',
            )
          else ...[
            _line('Temperature (C)', sensor['temperature']),
            _line('Humidity (%)', sensor['humidity']),
            _line('Weight (kg)', sensor['weight']),
            _line('Observed at', sensor['timestamp']),
          ],
          _line(
            'Bee activity sensor',
            'not connected in the current IoT contract',
          ),
          TextButton(
            onPressed: () => setState(() => _tab = 'Trends'),
            child: const Text('Review hive trends'),
          ),
        ],
      ),
      ColonySection(
        source: observation == null ? 'unavailable' : dataSource(observation),
        title: 'Latest beekeeper observation',
        icon: Icons.fact_check_outlined,
        children: [
          if (observation == null)
            _empty('No inspection observation saved yet.')
          else ...[
            _line('Observed on', observation['observed_on']),
            _line('Food stores', observation['food_stores']),
            _line('Brood', observation['brood']),
            _line('Flight activity', observation['bee_activity']),
          ],
          const Text(
            'Growth, food and population need direct observations. Weather alone does not establish favorable colony development.',
          ),
        ],
      ),
    ];
  }

  List<Widget> _observations() => [
    const ColonyNotice(
      'Beekeeper observations support environmental interpretation. Counts and estimates are not sensor measurements.',
    ),
    if (_items('observations').isEmpty)
      _empty(
        'No observations yet. Use Record observations to add an inspection.',
      ),
    for (final item in _items('observations'))
      ColonySection(
        source: dataSource(item),
        title: 'Inspection ${item['observed_on']}',
        icon: Icons.assignment_outlined,
        children: [
          _line('Queen', item['queen']),
          _line('Food stores', item['food_stores']),
          _line('Brood pattern', item['brood']),
          _line('Observed bee activity', item['bee_activity']),
          _line('Local forage', item['forage']),
          if (item['brood_frames'] != null)
            _line('Brood frames', item['brood_frames']),
          if (item['estimated_population'] != null)
            _line('User-estimated population', item['estimated_population']),
          if ((item['notes'] ?? '').toString().isNotEmpty)
            Text(item['notes'].toString(), style: colonyText(13)),
        ],
      ),
  ];
  List<Widget> _trends() {
    final sensors = _items('sensor_history')
      ..sort((a, b) => '${a['timestamp']}'.compareTo('${b['timestamp']}'));
    final values = sensors
        .where((s) => s[_metric] is num && (s[_metric] as num).isFinite)
        .toList();
    final unit = {
      'temperature': 'C',
      'humidity': '%',
      'weight': 'kg',
    }[_metric]!;
    return [
      ColonySection(
        source: _items('sensor_history').isEmpty
            ? 'unavailable'
            : dataSource(_items('sensor_history').first),
        title: 'In-hive trends',
        subtitle: 'Latest available IoT records. These values are not outdoor weather.',
        icon: Icons.show_chart,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['temperature', 'humidity', 'weight']
                .map(
                  (v) => ChoiceChip(
                    label: Text(_label(v)),
                    selected: _metric == v,
                    onSelected: (_) => setState(() => _metric = v),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          if (_data['sensor_error'] != null)
            ColonyNotice(_data['sensor_error'].toString()),
          if (values.length < 2)
            _empty(
              'At least two readings are needed to show a trend. No change or anomaly is inferred from missing data.',
            )
          else ...[
            Text(
              'Net recorded change: ${((values.last[_metric] as num) - (values.first[_metric] as num)).toStringAsFixed(2)} $unit',
              style: colonyText(18, FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${values.first['timestamp']} to ${values.last['timestamp']}',
              style: colonyText(11),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < values.length; i++)
                          FlSpot(
                            i.toDouble(),
                            (values[i][_metric] as num).toDouble(),
                          ),
                      ],
                      color: AppColors.accent3,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'Chart follows record order; timestamps are shown below. Net change is descriptive, not a validated risk threshold.',
              style: colonyText(11, FontWeight.w400, AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          for (final s in sensors.reversed.take(10))
            _line('${s['timestamp']}', '${s[_metric] ?? 'Unavailable'} $unit'),
        ],
      ),
      ColonySection(
        source: dataSource(_data),
        title: 'Observed flight & population',
        icon: Icons.visibility_outlined,
        children: [
          if (_items('observations').isEmpty)
            _empty(
              'Record flight activity and population estimates during inspections.',
            ),
          for (final o in _items('observations').take(10))
            _line(
              '${o['observed_on']} (beekeeper)',
              '${_label(o['bee_activity'])}; population estimate: ${o['estimated_population'] ?? 'not recorded'}',
            ),
        ],
      ),
    ];
  }

  List<Widget> _alerts() {
    final alerts = <Map<String, dynamic>>[
      for (final a in _assessment['alerts'] as List? ?? [])
        Map<String, dynamic>.from(a as Map),
      for (final r in _items(
        'records',
      ).where((r) => r['record_type'] == 'image_assessment').take(5))
        for (final a in (r['assessment'] as Map?)?['alerts'] as List? ?? [])
          if (a['source'] == 'Model A')
            {...Map<String, dynamic>.from(a as Map), 'saved_visual': true},
    ];
    final reviewed = _items('alert_reviews').map((r) => r['key']).toSet();
    final visible = alerts
        .where((a) => !_onlyUnread || !reviewed.contains(a['review_key']))
        .toList();
    return [
      const ColonyNotice(
        'Mark reviewed after checking the evidence. Reviewing an alert does not resolve its cause or confirm colony health.',
      ),
      if (_preferences['in_app_alerts'] != true)
        _empty(
          'In-app alert summaries are disabled in your settings. Evidence remains available here.',
        ),
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Needs review'),
            selected: _onlyUnread,
            onSelected: (_) => setState(() => _onlyUnread = true),
          ),
          ChoiceChip(
            label: const Text('All alerts'),
            selected: !_onlyUnread,
            onSelected: (_) => setState(() => _onlyUnread = false),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (visible.isEmpty)
        _empty(
          'No alerts in this view. Missing evidence does not mean the colony is healthy.',
        ),
      for (final a in visible)
        ColonySection(
          source: dataSource(_data),
          title: '${_label(a['severity'])} - ${a['source']}',
          icon: Icons.warning_amber_rounded,
          subtitle: a['saved_visual'] == true
              ? 'Saved visual finding; may not describe current conditions.'
              : 'Current monitoring evidence',
          children: [
            Text('${a['message']}', style: colonyText(14)),
            const SizedBox(height: 12),
            if (reviewed.contains(a['review_key']))
              const Text('Reviewed')
            else
              FilledButton.icon(
                onPressed: _busy || a['review_key'] == null
                    ? null
                    : () => _mutate(
                        () =>
                            widget.api.review(widget.hive.id, a['review_key']),
                        'Alert marked reviewed.',
                      ),
                icon: const Icon(Icons.done),
                label: const Text('Mark reviewed'),
              ),
            TextButton(
              onPressed: _carePlan,
              child: const Text('Create follow-up plan'),
            ),
          ],
        ),
    ];
  }

  List<Widget> _care() => [
    ColonySection(
      source: dataSource(_data),
      title: 'Management decision support',
      icon: Icons.eco_outlined,
      subtitle:
          'Choose a next step from available evidence and direct inspection.',
      children: [
        _line('Environmental watch', _assessment['environmental_risk']),
        _line('Visual disease indicators', _assessment['disease_risk']),
        const Text('''1. Review weather and verify unusual sensor readings.
2. Record brood, stores and flight observations.
3. Add a compatible bee/frame photo where helpful.
4. Discuss concerning findings with a qualified bee-health expert.'''),
        const SizedBox(height: 12),
        const ColonyNotice(
          'Treatment selection and dosing require expert advice and the applicable product label. This workspace records your agreed plan; it does not prescribe a treatment.',
        ),
      ],
    ),
    if (_items('care_plans').isEmpty)
      _empty('No follow-up plans yet. Tap Plan hive care to schedule one.'),
    for (final p in _items('care_plans'))
      ColonySection(
        source: dataSource(p),
        title: _label(p['action']),
        subtitle: 'Follow up: ${p['due_on']}',
        icon: Icons.event_note_outlined,
        children: [
          _line('Status', p['status']),
          if ((p['product'] ?? '').toString().isNotEmpty)
            _line('Expert-advised procedure', p['product']),
          if ((p['advisor'] ?? '').toString().isNotEmpty)
            _line('Advising expert', p['advisor']),
          Text('${p['notes']}', style: colonyText(13)),
          if (p['status'] == 'planned')
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => _mutate(
                      () => widget.api.complete(widget.hive.id, p['id']),
                      'Care plan marked completed.',
                    ),
              icon: const Icon(Icons.task_alt),
              label: const Text('Mark completed'),
            ),
        ],
      ),
  ];
  List<Widget> _images() {
    final images = _items('records')
        .where((r) => r['record_type'] == 'image_assessment')
        .toList();
    return [
      ColonySection(
        source: dataSource(_data),
        title: 'Bee & hive image evidence',
        icon: Icons.add_photo_alternate_outlined,
        children: [
          const Text(
            'Choose an individual-bee photo for Model A or a hive-frame photo for Model B. Compatible analysis can be saved with its assessment.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageModelAnalysisScreen(
                    hiveId: widget.hive.id,
                    location:
                        widget.apiary.gpsLocation?.trim().isNotEmpty == true
                        ? widget.apiary.gpsLocation
                        : widget.apiary.locationName,
                  ),
                ),
              );
              if (mounted) _load();
            },
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Add image evidence'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Backend history stores analysis only. Scores are not disease probabilities.',
          ),
        ],
      ),
      if (images.isEmpty) _empty('No saved image assessments for this hive.'),
      for (final r in images)
        ColonySection(
          source: dataSource(r),
          title: 'Saved image assessment',
          subtitle: '${r['saved_at']}',
          icon: Icons.image_search_outlined,
          children: [
            for (final key in ['model_a', 'model_b'])
              if (r[key] is Map) ...[
                _line(
                  key == 'model_a' ? 'Individual bee' : 'Frame structures',
                  (r[key] as Map)['predicted_class'] ??
                      (r[key] as Map)['status'],
                ),
                if ((r[key] as Map)['message'] != null)
                  Text('${(r[key] as Map)['message']}'),
                if ((r[key] as Map)['detections'] is List)
                  _line(
                    'Structural detections',
                    ((r[key] as Map)['detections'] as List).length,
                  ),
              ],
            if (r['assessment'] is Map)
              ColonyAssessmentCard(
                assessment: Map<String, dynamic>.from(r['assessment'] as Map),
                compact: true,
              ),
          ],
        ),
    ];
  }

  List<Widget> _settings() => [
    ColonySection(
      source: dataSource(_preferences),
      title: 'Monitoring preferences',
      icon: Icons.tune,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Refresh while this page is open'),
          subtitle: const Text('Paused when the app is in the background.'),
          value: _preferences['auto_refresh'] == true,
          onChanged: _busy
              ? null
              : (v) => _savePreferences({'auto_refresh': v}),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey(_preferences['refresh_seconds']),
          initialValue:
              (_preferences['refresh_seconds'] as num?)?.toInt() ?? 300,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Refresh interval'),
          items: const [
            DropdownMenuItem(value: 60, child: Text('Every minute')),
            DropdownMenuItem(value: 300, child: Text('Every 5 minutes')),
            DropdownMenuItem(value: 900, child: Text('Every 15 minutes')),
          ],
          onChanged: _busy
              ? null
              : (v) {
                  if (v != null) _savePreferences({'refresh_seconds': v});
                },
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('In-app alert summaries'),
          value: _preferences['in_app_alerts'] == true,
          onChanged: _busy
              ? null
              : (v) => _savePreferences({'in_app_alerts': v}),
        ),
        const SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Background push notifications'),
          subtitle: Text(
            'Delivery service is not connected. Alerts are available inside this workspace.',
          ),
          value: false,
          onChanged: null,
        ),
        const ColonyNotice(
          'Missing or stale readings stay unavailable. Alert review does not disable monitoring rules. No automated medicine or dose recommendations are enabled.',
        ),
      ],
    ),
  ];
  void _savePreferences(Map<String, dynamic> change) => _mutate(
    () => widget.api.preferences(widget.hive.id, {
      'auto_refresh': _preferences['auto_refresh'] == true,
      'refresh_seconds': _preferences['refresh_seconds'] ?? 300,
      'in_app_alerts': _preferences['in_app_alerts'] == true,
      ...change,
    }),
    'Monitoring preferences saved.',
  );
}
