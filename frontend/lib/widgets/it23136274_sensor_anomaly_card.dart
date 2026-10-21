import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/it23136274_colony_health_service.dart';
import '../utils/sensor_analytics.dart';
import '../utils/theme.dart';

/// IT23136274 - Card showing the experimental Isolation Forest V2 sensor anomaly
/// result for the latest reading. Never shows a health diagnosis or confidence.
class IT23136274SensorAnomalyCard extends StatelessWidget {
  final SensorAnomalyController controller;
  final String title;

  /// When set, the card is tappable and shows an "AI Assessment" link.
  final VoidCallback? onOpenDetails;

  const IT23136274SensorAnomalyCard({
    super.key,
    required this.controller,
    this.title = 'Sensor Anomaly Check',
    this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.lightGreenCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          ..._buildBody(),
          const SizedBox(height: 12),
          Text(
            'Experimental model: flags unusual temperature/humidity patterns only. '
            'It does not confirm colony health.',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );

    if (onOpenDetails == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(20),
        child: card,
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (onOpenDetails != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AI Assessment',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent2,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.accent2),
            ],
          ),
      ],
    );
  }

  List<Widget> _buildBody() {
    final result = controller.result;

    if (controller.loading && result == null) {
      return [
        _statusPill(
          text: 'Checking...',
          color: AppColors.textSecondary,
          icon: null,
        ),
        const SizedBox(height: 12),
        _message('Running the anomaly model on the latest sensor reading.'),
      ];
    }

    if (controller.error != null) {
      return [
        _statusPill(
          text: 'Prediction unavailable',
          color: AppColors.textSecondary,
          icon: Icons.cloud_off_rounded,
        ),
        const SizedBox(height: 12),
        _message(controller.error!),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: controller.retry,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AppColors.accent2,
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(
            'Retry',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ];
    }

    if (result == null) {
      return [
        _statusPill(
          text: controller.noReadings ? 'No sensor data' : 'Waiting for sensor data',
          color: AppColors.textSecondary,
          icon: Icons.sensors_off_rounded,
        ),
        const SizedBox(height: 12),
        _message(controller.noReadings
            ? 'No ESP32 readings found for this hive yet.'
            : 'The prediction runs when the latest sensor reading loads.'),
      ];
    }

    final inspect = result.inspectionRecommended;
    final timestamp = result.timestamp;
    return [
      Row(
        children: [
          Flexible(
            child: _statusPill(
              text: result.status,
              color: inspect ? AppColors.warning : AppColors.success,
              icon: inspect ? Icons.search_rounded : Icons.check_rounded,
            ),
          ),
          if (controller.loading) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      _message(result.recommendation, strong: true),
      const SizedBox(height: 6),
      _message(
        'Based on ${formatSensorValue(result.temperature, '°C')} • '
        '${formatSensorValue(result.humidity, '%')}'
        '${timestamp == null ? '' : ' • ${formatReadingTime(timestamp)}'}',
      ),
    ];
  }

  Widget _statusPill({required String text, required Color color, required IconData? icon}) {
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 14 : 6, 6, 16, 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.bgSecondary.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.bgSecondary, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.bgSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String text, {bool strong = false}) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
        color: strong ? AppColors.textPrimary : AppColors.textSecondary,
        height: 1.4,
      ),
    );
  }
}
