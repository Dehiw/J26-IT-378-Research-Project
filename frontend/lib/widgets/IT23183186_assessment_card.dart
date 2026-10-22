import 'package:flutter/material.dart';

import '../utils/theme.dart';
import '../services/environment_fallback.dart';
import 'environment_source.dart';

class ColonyAssessmentCard extends StatelessWidget {
  final Map<String, dynamic> assessment;
  final bool compact;
  final VoidCallback? onViewAll;
  const ColonyAssessmentCard({
    super.key,
    required this.assessment,
    this.compact = false,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final alerts = assessment['alerts'] as List? ?? [];
    final missing = assessment['missing_inputs'] as List? ?? [];
    if (compact) {
      final status = assessment['status'] == 'inconclusive'
          ? 'More evidence needed'
          : 'Checks to review';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: .035),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SourceDot(source: dataSource(assessment), compact: true),
                const SizedBox(width: 8),
                const Icon(Icons.shield_outlined, color: AppColors.accent3),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: AppColors.darkGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Checks weather and available hive readings, then suggests what to inspect.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              alerts.isEmpty
                  ? 'No alerts from the available data. This does not confirm hive health.'
                  : '${alerts.length} alerts to review for this location and hive.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text('${alerts.length} alerts'),
                  backgroundColor: AppColors.bgPrimary,
                  side: const BorderSide(color: AppColors.border),
                  labelStyle: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  avatar: const Icon(Icons.notifications_none, size: 16),
                ),
                Chip(
                  label: Text('${missing.length} missing inputs'),
                  backgroundColor: AppColors.badgeWaveBg,
                  side: BorderSide.none,
                  labelStyle: const TextStyle(
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                  ),
                  avatar: const Icon(Icons.info_outline, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final alert in alerts.take(2)) _alertRow(context, alert),
            if (missing.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.badgeWaveBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.sensors_off,
                      size: 20,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Needed for a fuller check: ${missing.join('; ')}',
                        style: const TextStyle(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            if (onViewAll != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onViewAll,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('View all monitoring suggestions'),
                ),
              ),
            Material(
              color: AppColors.bgSecondary,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Review evidence and rules'),
                children: [ColonyAssessmentCard(assessment: assessment)],
              ),
            ),
          ],
        ),
      );
    }
    return Card(
      color: AppColors.bgSecondary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SourceDot(source: dataSource(assessment)),
            Text(
              'Colony monitoring · ${assessment['status']}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(assessment['summary']?.toString() ?? ''),
            Text(
              'Environmental watch: ${assessment['environmental_risk'] ?? 'unknown'}',
            ),
            Text(
              'Disease indicators: ${assessment['disease_risk'] ?? 'unknown'}',
            ),
            const SizedBox(height: 12),
            const Text(
              'Current alerts',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (alerts.isEmpty)
              const Text(
                'No monitoring rule triggered with the available fresh inputs. This does not confirm colony health.',
              ),
            for (final alert in alerts) _alertRow(context, alert),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Missing evidence: ${missing.join('; ')}'),
            ],
            const SizedBox(height: 8),
            Text('Updated: ${assessment['generated_at'] ?? 'unavailable'}'),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Rules and limitations'),
              children: [
                Text(
                  'Monitoring rules ${displayIdentifier(assessment['rules_version'])}',
                ),
                for (final entry in (assessment['rules'] as Map? ?? {}).entries)
                  Text(
                    '${entry.key.toString().replaceAll('_', ' ')}: ${entry.value}',
                  ),
                for (final line in assessment['limitations'] as List? ?? [])
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('$line'),
                  ),
              ],
            ),
            const Text(
              'Alerts refresh when you open or refresh this page. Background/push notifications are not enabled.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertRow(BuildContext context, dynamic alert) {
    final weather = '${alert['source']}'.toLowerCase().contains('weather');
    final severity = alert['severity']?.toString() ?? 'unknown';
    final timestamp = alert['timestamp'] ?? alert['generated_at'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            weather ? Icons.cloud_outlined : Icons.monitor_heart_outlined,
            color: severity == 'high' ? AppColors.error : AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title']?.toString() ??
                      (weather
                          ? 'Outdoor weather warning'
                          : 'Colony monitoring alert'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
                Text('$severity \u00b7 ${alert['source'] ?? 'Unknown source'}'),
                const SizedBox(height: 6),
                Text(
                  alert['message']?.toString() ?? 'Explanation unavailable.',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                if (timestamp != null) Text('Observed: $timestamp'),
                TextButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        weather
                            ? 'Review outdoor conditions'
                            : 'Review colony evidence',
                      ),
                      content: SingleChildScrollView(
                        child: Text(
                          '${alert['message'] ?? 'Details unavailable.'}\n\nSource: ${alert['source'] ?? 'Unknown'}\nStatus: $severity${timestamp == null ? '' : '\nObserved: $timestamp'}',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(
                    weather ? 'Review weather guidance' : 'Review alert',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
