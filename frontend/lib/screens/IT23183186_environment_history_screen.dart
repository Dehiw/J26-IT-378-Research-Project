import 'package:flutter/material.dart';

import '../widgets/environment_source.dart';

import 'package:intl/intl.dart';

import '../services/IT23183186_colony_assessment_api.dart';
import '../utils/theme.dart';
import '../services/environment_fallback.dart';
import '../widgets/IT23183186_assessment_card.dart';

class IT23183186EnvironmentHistoryScreen extends StatefulWidget {
  final String hiveId;
  final String hiveName;
  final ColonyAssessmentApi api;
  const IT23183186EnvironmentHistoryScreen({
    super.key,
    required this.hiveId,
    required this.hiveName,
    this.api = const ColonyAssessmentApi(),
  });
  @override
  State<IT23183186EnvironmentHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<IT23183186EnvironmentHistoryScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await widget.api.fetchHistory(widget.hiveId);
      if (mounted) setState(() => _records = records);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load saved history. Check your connection and sign-in, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? 'Save time unavailable'
        : DateFormat('d MMM yyyy - HH:mm').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) => EnvironmentRecovery(
    needed: () =>
        EnvironmentFallback.instance.sourceFor('history/${widget.hiveId}') !=
        'live',
    onRetry: _load,
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    appBar: AppBar(
      title: const Text('Saved environment'),
      backgroundColor: AppColors.bgPrimary,
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.hiveName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Latest 20 saved snapshots. These are historical observations, not current conditions.',
            ),
            const SizedBox(height: 20),
            if (_loading)
              const LinearProgressIndicator()
            else if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.error)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ] else if (_records.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No snapshots saved yet. Return to Hive environment and tap Save snapshot.',
                ),
              )
            else
              for (final record in _records) _recordCard(context, record),
          ],
        ),
      ),
    ),
  );

  Widget _recordCard(BuildContext context, Map<String, dynamic> record) {
    final weather = record['weather'] as Map?;
    final current = weather?['current'] as Map?;
    final assessment = record['assessment'] as Map?;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SourceDot(source: dataSource(record), compact: true),
              const SizedBox(width: 8),
              const Icon(Icons.history_rounded, color: AppColors.accent3),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _date(record['saved_at']),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (record['local_only'] == true)
            const Text('Saved on this device only.'),
          Text('Location: ${record['location_query'] ?? 'Unavailable'}'),
          const SizedBox(height: 8),
          if (current == null)
            const Text('Outdoor weather was unavailable when saved.')
          else
            Text(
              'Outdoor: ${current['temperature_c'] ?? 'Unavailable'} \u00b0C | ${current['humidity_percent'] ?? 'Unavailable'}% humidity | ${current['precipitation_mm'] ?? 'Unavailable'} mm rain',
            ),
          if (current?['last_updated'] != null)
            Text('Weather observed: ${current!['last_updated']}'),
          const SizedBox(height: 8),
          if (assessment != null)
            ColonyAssessmentCard(
              assessment: Map<String, dynamic>.from(assessment),
              compact: true,
            ),
          Material(
            color: AppColors.bgCard,
            child: ExpansionTile(
              title: const Text('View saved assessment'),
              tilePadding: EdgeInsets.zero,
              children: [
                if (assessment != null)
                  ColonyAssessmentCard(
                    assessment: Map<String, dynamic>.from(assessment),
                  ),
                const SizedBox(height: 8),
                Text(
                  record['sensor'] == null
                      ? 'Hive sensor readings were unavailable.'
                      : 'Hive sensor observation: ${(record['sensor'] as Map)['timestamp'] ?? 'time unavailable'}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
