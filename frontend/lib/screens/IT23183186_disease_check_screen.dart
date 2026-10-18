import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/apiary_model.dart';
import '../services/apiary_service.dart';
import '../services/inference_service.dart';
import '../utils/theme.dart';
import 'IT23183186_disease_assessment_screen.dart';
import 'IT23183186_disease_risk_screen.dart';

class DiseaseCheckScreen extends StatelessWidget {
  final InferenceService? inferenceService;
  const DiseaseCheckScreen({super.key, this.inferenceService});

  @override
  Widget build(BuildContext context) {
    final ApiaryModel? apiary = ApiaryService.instance.selectedApiary;
    final modelReady = inferenceService?.isReady ?? false;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Disease check'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('COLONY HEALTH', style: _style(11, FontWeight.w700, AppColors.textSecondary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: _card(),
              child: Row(
                children: [
                  const Icon(Icons.hive_outlined, color: AppColors.accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      apiary?.locationName ?? 'No apiary selected',
                      style: _style(13, FontWeight.w600, AppColors.textPrimary),
                    ),
                  ),
                  Text('APIARY', style: _style(10, FontWeight.w600, AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.panelBlack,
                borderRadius: BorderRadius.circular(21),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    height: 78,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent, width: 5),
                      ),
                      child: Center(
                        child: Icon(
                          modelReady ? Icons.check_rounded : Icons.remove_rounded,
                          color: AppColors.bgPrimary,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _pill(modelReady ? 'Model ready' : 'Evidence needed', modelReady ? AppColors.accent3 : AppColors.warning),
                        const SizedBox(height: 9),
                        Text(
                          modelReady ? 'Ready for image assessment' : 'No assessment yet',
                          style: _style(17, FontWeight.w700, AppColors.bgPrimary),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          modelReady
                              ? 'Upload a clear brood or bee image to get a model result.'
                              : 'No disease model weights are bundled, so no score is reported.',
                          style: _style(11, FontWeight.w400, AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Available evidence', style: _style(16, FontWeight.w700, AppColors.textPrimary)),
            const SizedBox(height: 9),
            _evidenceRow(
              Icons.camera_alt_outlined,
              'Hive image model',
              modelReady ? 'Ready · 4 broad classes' : 'Unavailable · model files not bundled',
              modelReady ? AppColors.accent3 : AppColors.warning,
            ),
            _evidenceRow(
              Icons.speed_rounded,
              'In-hive sensors',
              'No connected hive sensor readings available',
              AppColors.textSecondary,
            ),
            _evidenceRow(
              Icons.graphic_eq_rounded,
              'Hive acoustics',
              'No audio recording or analysis available',
              AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'WeatherAPI readings describe outdoor weather; they are not treated as in-hive measurements or disease evidence.',
              style: _style(11, FontWeight.w400, AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DiseaseAssessmentScreen(inferenceService: inferenceService),
                ),
              ),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Upload hive image'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DiseaseRiskScreen(inferenceService: inferenceService),
                ),
              ),
              icon: const Icon(Icons.assessment_outlined),
              label: const Text('View risk overview'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _evidenceRow(IconData icon, String title, String detail, Color color) =>
    Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: _card(),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _style(13, FontWeight.w700, AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(detail, style: _style(11, FontWeight.w400, AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );

Widget _pill(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(20)),
  child: Text(label, style: _style(10, FontWeight.w700, color)),
);

BoxDecoration _card() => BoxDecoration(
  color: AppColors.bgSecondary,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: AppColors.border),
);

TextStyle _style(double size, FontWeight weight, Color color) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

