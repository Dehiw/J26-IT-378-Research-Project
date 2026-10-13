import 'dart:typed_data';
import 'prediction_result.dart';

/// Web stand-in for the ONNX-backed service in inference_service_native.dart.
///
/// On-device inference is not available in a browser, so [init] throws and
/// the caller degrades to demo mode (see main.dart _AppLoader), exactly as it
/// does on mobile when the model files are not bundled.
class InferenceService {
  static const int imgSize = 224;
  static const List<double> mean = [0.485, 0.456, 0.406];
  static const List<double> std = [0.229, 0.224, 0.225];

  static const List<String> classNames = [
    'Healthy Colony',
    'Stressed Colony',
    'Disease Signs',
    'Empty / Other',
  ];

  static const double defaultOodThreshold = 1e9;

  bool get isReady => false;
  bool get isOodConfigLoaded => false;
  double get activeOodThreshold => defaultOodThreshold;

  Future<void> init() async {
    throw UnsupportedError(
      'On-device ONNX inference is not supported in the web browser.',
    );
  }

  void setOodConfig({
    required List<Float32List> classMeans,
    required Float32List precisionMatrix,
    required double threshold,
  }) {}

  Future<PredictionResult> predict(Uint8List imageBytes) async {
    throw UnsupportedError(
      'On-device ONNX inference is not supported in the web browser.',
    );
  }

  void dispose() {}
}
