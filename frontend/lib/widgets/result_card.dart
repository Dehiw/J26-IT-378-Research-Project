import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';
import '../services/inference_service.dart';
import 'confidence_bar.dart';

class ResultCard extends StatelessWidget {
  final PredictionResult result;

  const ResultCard({super.key, required this.result});

  // ── Hive-health metadata matching InferenceService.classNames ──
  static const Map<String, _HealthInfo> _healthInfo = {
    'Healthy Colony': _HealthInfo(
      icon: '🐝',
      description:
          'No stress signs detected. The colony appears active with normal behavior. Continue regular monitoring and forage checks.',
      severity: 'Good',
      severityColor: Color(0xFF4C8C4A),
    ),
    'Stressed Colony': _HealthInfo(
      icon: '⚠️',
      description:
          'Early stress indicators detected — check temperature, humidity and noise levels. Inspect for overcrowding or poor ventilation.',
      severity: 'Watch',
      severityColor: Color(0xFFC98A1B),
    ),
    'Disease Signs': _HealthInfo(
      icon: '🦠',
      description:
          'Possible disease or parasite signs. Inspect brood frames closely, consider expert review, and isolate if symptoms spread.',
      severity: 'High',
      severityColor: Color(0xFFB44436),
    ),
    'Empty / Other': _HealthInfo(
      icon: '🍂',
      description:
          'No active colony detected in this image. Check hive occupancy or retake with the entrance frames clearly visible.',
      severity: 'Info',
      severityColor: Color(0xFF3A4A63),
    ),
    'OOD — Rejected': _HealthInfo(
      icon: '🚨',
      description:
          'The image does not resemble a beehive based on the model\'s distribution. Please use a clear, close-up photo of the hive.',
      severity: 'N/A',
      severityColor: Color(0xFF6B5B3E),
    ),
  };

  Color get _statusColor {
    if (result.isOod) return AppColors.purple;
    if (result.predictedClass == 'Healthy Colony') return AppColors.success;
    if (result.confidence >= 0.75) return AppColors.error;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final info =
        _healthInfo[result.predictedClass] ?? _healthInfo['OOD — Rejected']!;

    // Sort class scores descending
    final sortedScores = result.classScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Animate(
      effects: [
        FadeEffect(duration: 400.ms),
        SlideEffect(
          duration: 400.ms,
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Primary result banner ─────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: _statusColor.withValues(alpha: 0.4), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(info.icon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.predictedClass,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _statusColor,
                            ),
                          ),
                          if (!result.isOod)
                            Text(
                              'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Severity badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: info.severityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: info.severityColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        info.severity,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: info.severityColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  info.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── OOD status row ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  result.isOod
                      ? Icons.warning_amber_rounded
                      : Icons.verified_rounded,
                  size: 16,
                  color: result.isOod ? AppColors.warning : AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  result.isOod ? 'Out-of-Distribution' : 'In-Distribution',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: result.isOod ? AppColors.warning : AppColors.success,
                  ),
                ),
                const Spacer(),
                if (result.oodScore > 0) ...[
                  Text(
                    'OOD Score: ${result.oodScore.toStringAsFixed(1)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '/ ${result.oodThreshold.toStringAsFixed(1)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Per-class confidence bars ─────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Probabilities',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...sortedScores.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  return ConfidenceBar(
                    label: e.key,
                    confidence: e.value,
                    isTopPrediction: i == 0 && !result.isOod,
                    animationDelayMs: i * 80,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthInfo {
  final String icon;
  final String description;
  final String severity;
  final Color severityColor;

  const _HealthInfo({
    required this.icon,
    required this.description,
    required this.severity,
    required this.severityColor,
  });
}
