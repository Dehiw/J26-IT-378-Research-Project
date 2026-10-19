import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

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

/// Wraps the two ONNX models (classifier + feature extractor)
/// and the OOD Mahalanobis detector exported from the training notebook.
///
/// Model files expected in assets/models/ (declared in pubspec.yaml):
///   - hive_model.onnx
///   - feature_extractor.onnx
///   - labels.json
///   - ood_config.json
///
/// If the model files are not bundled yet, [init] throws and the caller
/// can degrade gracefully (see main.dart _AppLoader).
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

  /// OOD only triggers on truly out-of-distribution images when
  /// ood_config.json fails to load. The real threshold comes from
  /// ood_config.json (exported by notebook).
  static const double defaultOodThreshold = 1e9;

  OrtSession? _classifierSession;
  OrtSession? _featExtractorSession;

  // Class means (N x 1280) and precision matrix (1280 x 1280)
  List<Float32List>? _classMeans;
  Float32List? _precisionMatrix;
  double _oodThreshold = defaultOodThreshold;

  bool _initialized = false;
  bool _oodConfigLoaded = false;

  /// True after a successful [init]. Home screen disables analysis
  /// when false and shows a "model not bundled" banner instead.
  bool get isReady => _initialized;
  bool get isOodConfigLoaded => _oodConfigLoaded;
  double get activeOodThreshold => _oodThreshold;

  // ── Initialise ───────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    OrtEnv.instance.init();

    // Load classifier
    final classifierData =
        await rootBundle.load('assets/models/hive_model.onnx');
    _classifierSession = OrtSession.fromBuffer(
      classifierData.buffer.asUint8List(),
      OrtSessionOptions(),
    );

    // Load feature extractor
    final featData =
        await rootBundle.load('assets/models/feature_extractor.onnx');
    _featExtractorSession = OrtSession.fromBuffer(
      featData.buffer.asUint8List(),
      OrtSessionOptions(),
    );

    try {
      await _loadOodConfig();
      _oodConfigLoaded = true;
      developer.log(
        'OOD config loaded — threshold: $_oodThreshold',
        name: 'InferenceService',
      );
    } catch (e, stack) {
      developer.log(
        'ood_config.json failed to load: $e. '
        'Falling back to disabled OOD (threshold=1e9). '
        'Check that assets/models/ood_config.json is declared in pubspec.yaml.',
        name: 'InferenceService',
        error: e,
        stackTrace: stack,
      );
    }

    _initialized = true;
  }

  Future<void> _loadOodConfig() async {
    final jsonStr =
        await rootBundle.loadString('assets/models/ood_config.json');

    final Map<String, dynamic> cfg =
        jsonDecode(jsonStr) as Map<String, dynamic>;

    _oodThreshold = (cfg['ood_threshold'] as num).toDouble();

    final rawMeans = cfg['class_means'] as List<dynamic>;
    _classMeans = rawMeans.map<Float32List>((dynamic row) {
      final rowList = row as List<dynamic>;
      return Float32List.fromList(
        rowList.map<double>((dynamic v) => (v as num).toDouble()).toList(),
      );
    }).toList();

    final rawPrec = cfg['precision_matrix'] as List<dynamic>;
    final flat = rawPrec
        .expand<double>((dynamic row) => (row as List<dynamic>)
            .map<double>((dynamic v) => (v as num).toDouble()))
        .toList();
    _precisionMatrix = Float32List.fromList(flat);
  }

  // ── Allow runtime injection of OOD config ────────────────
  void setOodConfig({
    required List<Float32List> classMeans,
    required Float32List precisionMatrix,
    required double threshold,
  }) {
    _classMeans = classMeans;
    _precisionMatrix = precisionMatrix;
    _oodThreshold = threshold;
    _oodConfigLoaded = true;
  }

  // ── Preprocess image to [1, 3, 224, 224] float32 ─────────
  Float32List _preprocess(img.Image image) {
    final resized = img.copyResize(image, width: imgSize, height: imgSize);
    final buffer = Float32List(1 * 3 * imgSize * imgSize);
    int idx = 0;

    // Channel-first layout: R plane, G plane, B plane
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < imgSize; y++) {
        for (int x = 0; x < imgSize; x++) {
          final pixel = resized.getPixel(x, y);
          double val;
          if (c == 0) {
            val = pixel.r / 255.0;
          } else if (c == 1) {
            val = pixel.g / 255.0;
          } else {
            val = pixel.b / 255.0;
          }
          buffer[idx++] = (val - mean[c]) / std[c];
        }
      }
    }
    return buffer;
  }

  // ── Softmax ──────────────────────────────────────────────
  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce(max);
    final exps = logits.map((v) => exp(v - maxVal)).toList();
    final sumExp = exps.reduce((a, b) => a + b);
    return exps.map((v) => v / sumExp).toList();
  }

  // ── Extract flat float list from ONNX output value ───────
  List<double> _extractFloats(OrtValue ortValue) {
    final raw = ortValue.value;

    // Most common: batch-wrapped list  [[f0, f1, ...]]
    if (raw is List && raw.isNotEmpty && raw.first is List) {
      return (raw.first as List)
          .map<double>((v) => (v as num).toDouble())
          .toList();
    }

    // Flat list of doubles
    if (raw is List<double>) {
      return raw;
    }

    // Float32List / typed data
    if (raw is Float32List) {
      return raw.map((v) => v.toDouble()).toList();
    }

    // Generic list fallback
    if (raw is List) {
      return raw.map<double>((v) => (v as num).toDouble()).toList();
    }

    throw Exception('Unexpected ONNX output type: ${raw.runtimeType}');
  }

  // ── Mahalanobis distance (pure Dart, no BLAS) ────────────
  double _mahalanobisScore(Float32List features) {
    if (_classMeans == null || _precisionMatrix == null) {
      return 0.0; // OOD config not loaded — skip OOD detection
    }
    double minDist = double.infinity;
    final dim = features.length; // 1280

    for (final mu in _classMeans!) {
      // diff = features - mu
      final diff = Float32List(dim);
      for (int i = 0; i < dim; i++) {
        diff[i] = features[i] - mu[i];
      }
      // left = diff @ precision  (row vector x matrix)
      final left = Float32List(dim);
      for (int j = 0; j < dim; j++) {
        double sum = 0.0;
        for (int i = 0; i < dim; i++) {
          sum += diff[i] * _precisionMatrix![i * dim + j];
        }
        left[j] = sum;
      }
      // d2 = left . diff
      double d2 = 0.0;
      for (int i = 0; i < dim; i++) {
        d2 += left[i] * diff[i];
      }
      if (d2 < minDist) minDist = d2;
    }
    return minDist;
  }

  // ── Main inference entry point ────────────────────────────
  Future<PredictionResult> predict(Uint8List imageBytes) async {
    assert(_initialized, 'Call init() before predict()');

    // Decode image
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('Failed to decode image');

    final inputTensor = _preprocess(decoded);
    final shape = [1, 3, imgSize, imgSize];

    // ── Step A: Classification ────────────────────────────
    final classInput = OrtValueTensor.createTensorWithDataList(
      inputTensor,
      shape,
    );
    final classRunOptions = OrtRunOptions();
    final classOutputs = await _classifierSession!.runAsync(
      classRunOptions,
      {'input': classInput},
    );

    final logitsList = _extractFloats(classOutputs![0]!);
    final probs = _softmax(logitsList);

    classInput.release();
    classRunOptions.release();
    for (var v in classOutputs) {
      v?.release();
    }

    final predIdx = probs.indexOf(probs.reduce(max));
    final confidence = probs[predIdx];

    developer.log(
      'Logits: $logitsList\n'
      'Probs: $probs\n'
      'PredIdx: $predIdx  Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
      name: 'InferenceService',
    );

    // ── Step B: Feature extraction (for OOD) ─────────────
    double oodScore = 0.0;
    bool isOod = false;

    if (_classMeans != null && _precisionMatrix != null) {
      final featInput = OrtValueTensor.createTensorWithDataList(
        inputTensor,
        shape,
      );
      final featRunOptions = OrtRunOptions();
      final featOutputs = await _featExtractorSession!.runAsync(
        featRunOptions,
        {'input': featInput},
      );

      final featList = _extractFloats(featOutputs![0]!);
      final features = Float32List.fromList(featList);

      featInput.release();
      featRunOptions.release();
      for (var v in featOutputs) {
        v?.release();
      }

      // ── Step C: Mahalanobis OOD scoring ───────────────
      oodScore = _mahalanobisScore(features);
      isOod = oodScore > _oodThreshold;

      developer.log(
        'OOD score: ${oodScore.toStringAsFixed(2)}  '
        'threshold: ${_oodThreshold.toStringAsFixed(2)}  '
        'rejected: $isOod  '
        'config_loaded: $_oodConfigLoaded',
        name: 'InferenceService',
      );
    }

    final classScores = {
      for (int i = 0; i < classNames.length; i++) classNames[i]: probs[i],
    };

    return PredictionResult(
      predictedClass: isOod ? 'OOD — Rejected' : classNames[predIdx],
      confidence: confidence,
      oodScore: oodScore,
      oodThreshold: _oodThreshold,
      isOod: isOod,
      classScores: classScores,
    );
  }

  void dispose() {
    _classifierSession?.release();
    _featExtractorSession?.release();
    OrtEnv.instance.release();
  }
}
