import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:frontend/models/IT23139930_acoustic_result.dart';
import 'package:frontend/models/IT23139930_hive_option.dart';
import 'package:frontend/services/IT23139930_acoustic_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/utils/api_config.dart';

/// Real acoustic analysis through the backend (`/acoustic/...`). The model
/// runs on the server. Every failure becomes an [AcousticException] with a
/// message the screens can show; nothing falls back to a made-up result.
class HttpAcousticService implements AcousticService {
  HttpAcousticService({
    required this._hivesProvider,
    http.Client? client,
    String? Function()? tokenProvider,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _token = tokenProvider ?? (() => AuthService.instance.token),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final Future<List<HiveOption>> Function() _hivesProvider;
  final http.Client _client;
  final String? Function() _token;
  final String _baseUrl;

  static const Duration _analyzeTimeout = Duration(seconds: 90);
  static const Duration _requestTimeout = Duration(seconds: 15);

  @override
  bool get isDemo => false;

  @override
  Future<AcousticResult> analyzeAudio({
    required String hiveId,
    required Uint8List bytes,
    required String filename,
  }) async {
    if (bytes.isEmpty) {
      throw const AcousticException('The recording is empty.');
    }
    final request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/acoustic/analyze'))
          ..headers.addAll(_headers())
          ..fields['hive_id'] = hiveId
          ..fields['source'] = _sourceFor(filename)
          ..files.add(
            http.MultipartFile.fromBytes('audio', bytes, filename: filename),
          );
    final json = await _send(
      () async => http.Response.fromStream(
        await _client.send(request).timeout(_analyzeTimeout),
      ),
      timeout: _analyzeTimeout,
    );
    return _parseResult(json);
  }

  @override
  Future<void> saveResult(
    AcousticResult result, {
    List<double> waveform = const [],
  }) async {
    await _send(
      () => _client.post(
        Uri.parse('$_baseUrl/acoustic/results/${result.id}/save'),
        headers: _headers(),
      ),
    );
  }

  @override
  Future<List<AcousticResult>> getHistory({String? hiveId}) async {
    final uri = Uri.parse('$_baseUrl/acoustic/history').replace(
      queryParameters: {'hive_id': ?hiveId},
    );
    final json = await _send(() => _client.get(uri, headers: _headers()));
    final list = json['results'];
    if (list is! List) return const [];
    return [
      for (final item in list) _parseResult(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<HiveOption>> getHives() => _hivesProvider();

  /// The backend keeps no waveform, so the preview is hidden for history.
  @override
  Future<List<double>?> getWaveform(String resultId) async => null;

  // Recordings are named "hive_<id>_<time>.wav" by the recorder; anything
  // else was picked by the user.
  static String _sourceFor(String filename) =>
      filename.startsWith('hive_') ? 'record' : 'upload';

  Map<String, String> _headers() {
    final token = _token();
    return {
      'accept': 'application/json',
      if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() call, {
    Duration timeout = _requestTimeout,
  }) async {
    final http.Response response;
    try {
      response = await call().timeout(timeout);
    } on TimeoutException {
      throw const AcousticException(
        'The server took too long to answer. Please try again.',
      );
    } on http.ClientException {
      throw const AcousticException(
        'Cannot reach the server. Check that the backend is running.',
      );
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    final code = response.statusCode;
    if (code >= 200 && code < 300) {
      return body ?? const {};
    }
    final detail = body?['detail'];
    final text = detail is String ? detail : null;
    throw AcousticException(switch (code) {
      401 => 'Your session has expired. Please log in again.',
      503 => text ?? 'Acoustic model not available.',
      400 || 403 || 404 || 413 => text ?? 'The request was rejected.',
      _ => text ?? 'Server error ($code). Please try again.',
    });
  }

  static AcousticResult _parseResult(Map<String, dynamic> json) {
    return AcousticResult(
      id: json['id'] as String,
      hiveId: json['hive_id'] as String,
      label: _labelFrom(json['label'] as String?),
      confidence: (json['confidence'] as num).toDouble().clamp(0.0, 1.0),
      recordedAt:
          DateTime.tryParse(json['analyzed_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      audioQuality: _qualityFrom(json['audio_quality'] as String?),
      modelVersion: json['model_version'] as String? ?? 'unknown',
    );
  }

  // The model has two classes. Anything else is not trusted as a state.
  static AcousticLabel _labelFrom(String? value) => switch (value) {
    'normal' => AcousticLabel.normal,
    'queenless' => AcousticLabel.queenless,
    'swarming' => AcousticLabel.swarming,
    'stress_abnormal' => AcousticLabel.stressAbnormal,
    _ => AcousticLabel.unclearRecording,
  };

  static AudioQuality _qualityFrom(String? value) => switch (value) {
    'fair' => AudioQuality.fair,
    'poor' => AudioQuality.poor,
    _ => AudioQuality.good,
  };
}
