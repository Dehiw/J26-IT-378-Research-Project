import 'dart:typed_data';

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

/// Browser fallback. ONNX Runtime's current Flutter package uses dart:ffi,
/// which isn't available in the browser. The app therefore opens in demo mode.
class InferenceService {
  bool get isReady => false;

  Future<void> init() async {
    throw UnsupportedError('On-device inference is unavailable in the browser.');
  }

  Future<PredictionResult> predict(Uint8List imageBytes) async {
    throw UnsupportedError('On-device inference is unavailable in the browser.');
  }

  void dispose() {}
}
