import 'package:flutter/material.dart';

import '../utils/theme.dart';

class ColonyAssessmentCard extends StatelessWidget {
  final Map<String, dynamic> assessment;
  final bool compact;
  const ColonyAssessmentCard({
    super.key,
    required this.assessment,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final alerts = assessment['alerts'] as List? ?? [];
    final missing = assessment['missing_inputs'] as List? ?? [];
    if (compact) {
      final status = assessment['status'] == 'inconclusive'
          ? 'More evidence needed'
          : 'Preliminary findings';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.accent3),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alerts.isEmpty
                  ? 'No actionable finding from the available evidence. Missing inputs do not mean the colony is healthy.'
                  : '${alerts.length} monitoring alert(s) need review.',
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
                  avatar: const Icon(Icons.notifications_none, size: 16),
                ),
                Chip(
                  label: Text('${missing.length} missing inputs'),
                  avatar: const Icon(Icons.info_outline, size: 16),
                ),
              ],
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
            Text(
              'Colony monitoring · ${assessment['status']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(assessment['summary']?.toString() ?? ''),
            Text('Environmental watch: ${assessment['environmental_risk']}'),
            Text('Disease indicators: ${assessment['disease_risk']}'),
            const SizedBox(height: 12),
            const Text(
              'Current alerts',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (alerts.isEmpty)
              const Text(
                'No monitoring rule triggered with the available fresh inputs. This does not confirm colony health.',
              ),
            for (final alert in alerts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: alert['severity'] == 'high'
                      ? AppColors.error
                      : AppColors.warning,
                ),
                title: Text('${alert['severity']} · ${alert['source']}'),
                subtitle: Text('${alert['message']}'),
              ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Missing evidence: ${missing.join('; ')}'),
            ],
            const SizedBox(height: 8),
            Text('Updated: ${assessment['generated_at']}'),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Rules and limitations'),
              children: [
                Text('${assessment['rules_version']}'),
                for (final entry in (assessment['rules'] as Map? ?? {}).entries)
                  Text('${entry.key}: ${entry.value}'),
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
}
