import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/disease_risk_service.dart';
import '../services/inference_service.dart';
import '../utils/theme.dart';
import 'IT23183186_disease_assessment_screen.dart';

class DiseaseRiskScreen extends StatelessWidget {
  final PredictionResult? predictionResult;
  final InferenceService? inferenceService;

  const DiseaseRiskScreen({
    super.key,
    this.predictionResult,
    this.inferenceService,
  });

  @override
  Widget build(BuildContext context) {
    final assessment = predictionResult == null
        ? null
        : const DiseaseRiskService().assess(predictionResult!);
    final scoreColor = assessment == null || assessment.score < 30
        ? AppColors.accent3
        : assessment.score < 60
        ? AppColors.warning
        : AppColors.error;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Disease Risk Overview'),
        actions: [
          IconButton(
            tooltip: 'Assessment guidance',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'Hive Sense',
              children: const [
                Text('This baseline summarizes classifier outputs. It is not a veterinary diagnosis or calibrated disease probability.'),
              ],
            ),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          children: [
            _scoreCard(assessment, scoreColor),
            const SizedBox(height: 18),
            Text(
              'Model evidence',
              style: _style(16, FontWeight.w700, AppColors.textPrimary),
            ),
            const SizedBox(height: 9),
            if (assessment == null) ...[
              _emptyEvidence(),
            ] else ...[
              for (final entry in assessment.classScores.entries)
                _scoreRow(entry.key, entry.value),
              const SizedBox(height: 4),
              Text(
                'Baseline score = Disease Signs + Stressed Colony model scores. The model has four broad classes and cannot identify a specific disease.',
                style: _style(11, FontWeight.w400, AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DiseaseAssessmentScreen(
                    inferenceService: inferenceService,
                  ),
                ),
              ),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Upload hive image'),
            ),
            const SizedBox(height: 9),
            Text(
              'A photo assessment requires the ONNX model files to be bundled in the app.',
              textAlign: TextAlign.center,
              style: _style(11, FontWeight.w400, AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreCard(DiseaseRiskAssessment? assessment, Color scoreColor) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Text(
              'Initial image-risk indicator',
              style: _style(14, FontWeight.w600, AppColors.textPrimary),
            ),
            const SizedBox(height: 13),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scoreColor, width: 5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    assessment == null || predictionResult!.isOod
                        ? '—'
                        : '${assessment.score}',
                    style: _style(34, FontWeight.w800, AppColors.textPrimary),
                  ),
                  Text('/ 100', style: _style(12, FontWeight.w500, AppColors.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                assessment?.level ?? 'Awaiting image evidence',
                style: _style(11, FontWeight.w700, AppColors.bgPrimary),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              assessment?.explanation ??
                  'No image inference is available yet. Upload a hive image when a compatible model is bundled.',
              textAlign: TextAlign.center,
              style: _style(11, FontWeight.w500, AppColors.textPrimary),
            ),
          ],
        ),
      );

  Widget _emptyEvidence() => Container(
    padding: const EdgeInsets.all(16),
    decoration: _card(),
    child: Row(
      children: [
        const Icon(Icons.photo_camera_back_outlined, color: AppColors.warning),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            'No model result to assess. The repository currently has no ONNX weights, so no disease score or condition findings are shown.',
            style: _style(12, FontWeight.w500, AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );

  Widget _scoreRow(String name, double score) {
    final color = switch (name) {
      'Disease Signs' => AppColors.error,
      'Stressed Colony' => AppColors.warning,
      'Healthy Colony' => AppColors.accent3,
      _ => AppColors.blue,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: _card(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: _style(13, FontWeight.w700, AppColors.textPrimary))),
              Text('${(score * 100).toStringAsFixed(1)}%', style: _style(12, FontWeight.w700, color)),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score.clamp(0, 1),
              minHeight: 6,
              color: color,
              backgroundColor: AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _card() => BoxDecoration(
  color: AppColors.bgSecondary,
  borderRadius: BorderRadius.circular(17),
  border: Border.all(color: AppColors.border),
);

TextStyle _style(double size, FontWeight weight, Color color) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

