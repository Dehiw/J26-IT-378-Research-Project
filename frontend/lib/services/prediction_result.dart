/// Result from a single hive-health inference pass.
class PredictionResult {
  final String predictedClass;
  final double confidence;
  final double oodScore;
  final double oodThreshold;
  final bool isOod;
  final Map<String, double> classScores;

  const PredictionResult({
    required this.predictedClass,
    required this.confidence,
    required this.oodScore,
    required this.oodThreshold,
    required this.isOod,
    required this.classScores,
  });
}
