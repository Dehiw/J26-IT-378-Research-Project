import 'inference_service.dart';

/// A transparent baseline indicator derived only from the bundled classifier's
/// class scores. It is a prioritization aid, not a disease probability.
class DiseaseRiskAssessment {
  final int score;
  final String level;
  final String explanation;
  final Map<String, double> classScores;

  const DiseaseRiskAssessment({
    required this.score,
    required this.level,
    required this.explanation,
    required this.classScores,
  });
}

class DiseaseRiskService {
  const DiseaseRiskService();

  DiseaseRiskAssessment assess(PredictionResult result) {
    final disease = result.classScores['Disease Signs'] ?? 0;
    final stressed = result.classScores['Stressed Colony'] ?? 0;
    final healthy = result.classScores['Healthy Colony'] ?? 0;
    final score = ((disease + stressed) * 100).round().clamp(0, 100);

    final String level;
    final String explanation;
    if (result.isOod) {
      level = 'Uncertain';
      explanation = 'The image is outside the model training distribution.';
    } else if (disease >= 0.60 || score >= 60) {
      level = 'Elevated image signal';
      explanation = 'The model assigned a strong score to Disease Signs or colony stress.';
    } else if (score >= 30) {
      level = 'Monitor';
      explanation = 'The model found a moderate disease-sign or stress signal.';
    } else if (healthy >= 0.60) {
      level = 'Lower image signal';
      explanation = 'The model favored Healthy Colony for the submitted image.';
    } else {
      level = 'Uncertain';
      explanation = 'The model did not produce a strong healthy or disease-sign signal.';
    }

    return DiseaseRiskAssessment(
      score: score,
      level: level,
      explanation: explanation,
      classScores: result.classScores,
    );
  }
}
