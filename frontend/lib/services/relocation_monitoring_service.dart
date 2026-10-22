import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../utils/api_config.dart';
import 'auth_service.dart';

/// Research Component IT23185302:
/// Client for Post-Relocation Monitoring (ESP32-CAM + computer vision) via
/// the FastAPI backend.
///
/// Expected backend routes (all scoped to a hive box id):
///   GET  /relocation-monitoring/{hive_id}/status    → camera + session state
///   GET  /relocation-monitoring/{hive_id}/snapshot  → latest JPEG frame
///   GET  /relocation-monitoring/{hive_id}/activity  → readings + analysis
///   POST /relocation-monitoring/{hive_id}/start     → start a session
///   POST /relocation-monitoring/{hive_id}/stop      → stop the session
///
/// If the backend does not expose these routes yet, calls throw
/// [MonitoringUnavailableException] so the UI can show an honest state
/// instead of placeholder data.
class RelocationMonitoringService {
  static final RelocationMonitoringService instance =
      RelocationMonitoringService._internal();
  RelocationMonitoringService._internal();

  String _base(String hiveId) =>
      '${ApiConfig.baseUrl}/relocation-monitoring/$hiveId';

  Future<MonitoringStatus> fetchStatus(String hiveId) async {
    final res = await _getJson('${_base(hiveId)}/status');
    return MonitoringStatus.fromJson(res);
  }

  Future<ActivitySnapshot> fetchActivity(String hiveId) async {
    final res = await _getJson('${_base(hiveId)}/activity');
    return ActivitySnapshot.fromJson(res);
  }

  /// Latest camera frame, or null when the camera has no frame available.
  Future<Uint8List?> fetchSnapshot(String hiveId) async {
    final token = AuthService.instance.token;
    try {
      final response = await http.get(
        Uri.parse('${_base(hiveId)}/snapshot'),
        headers: {
          'accept': 'image/jpeg',
          if (token != null) 'authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 404) {
        throw const MonitoringUnavailableException();
      }
      if (response.statusCode == 204) return null;
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          type.startsWith('image/') &&
          response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      return null;
    } on http.ClientException {
      throw const AuthException('Cannot connect to backend server.');
    }
  }

  Future<MonitoringStatus> startMonitoring(String hiveId) async {
    final res = await _postJson('${_base(hiveId)}/start');
    return MonitoringStatus.fromJson(res);
  }

  Future<MonitoringStatus> stopMonitoring(String hiveId) async {
    final res = await _postJson('${_base(hiveId)}/stop');
    return MonitoringStatus.fromJson(res);
  }

  /// Runs the trained bee detection model on one image.
  ///
  /// POST /bee-detection/detect (multipart field `image`). [source] is
  /// 'upload' for user-selected images; ESP32-CAM frames will use
  /// 'esp32cam' on the same endpoint once the camera is integrated.
  Future<BeeDetectionResult> detectBees(
    Uint8List imageBytes, {
    String filename = 'bees.jpg',
    String source = 'upload',
    String? hiveId,
  }) async {
    if (imageBytes.isEmpty) {
      throw const BeeDetectionException('The selected image is empty.');
    }
    if (imageBytes.length > 10 * 1024 * 1024) {
      throw const BeeDetectionException('The image must be 10 MB or smaller.');
    }
    final token = AuthService.instance.token;
    if (token == null || token.isEmpty) {
      throw const BeeDetectionException('Sign in to run bee detection.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/bee-detection/detect'),
    )
      ..headers['authorization'] = 'Bearer $token'
      ..headers['accept'] = 'application/json'
      ..fields['source'] = source
      ..files.add(http.MultipartFile.fromBytes('image', imageBytes,
          filename: filename));
    if (hiveId != null) request.fields['hive_id'] = hiveId;

    final http.Response response;
    try {
      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      response = await http.Response.fromStream(streamed);
    } catch (e) {
      developer.log('Bee detection request failed: $e',
          name: 'RelocationMonitoring');
      throw const BeeDetectionException(
          'Cannot reach the backend. Check that the FastAPI server is running '
          'and the app is pointed at its address.');
    }

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300 && json != null) {
      return BeeDetectionResult.fromJson(json);
    }
    final detail = json?['detail'];
    throw BeeDetectionException(switch (response.statusCode) {
      401 => 'Your session has expired. Please sign in again.',
      404 => 'Bee detection is not available on this server version.',
      _ when detail is String => detail,
      _ => 'Bee detection failed (HTTP ${response.statusCode}).',
    });
  }

  // ── Internal ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getJson(String url) async {
    final token = AuthService.instance.token;
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'accept': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 12));
      return _decode(response);
    } on http.ClientException {
      throw const AuthException('Cannot connect to backend server.');
    } catch (e) {
      if (e is AuthException || e is MonitoringUnavailableException) rethrow;
      developer.log('Monitoring GET failed: $e', name: 'RelocationMonitoring');
      throw AuthException(e.toString());
    }
  }

  Future<Map<String, dynamic>> _postJson(String url) async {
    final token = AuthService.instance.token;
    try {
      final response = await http.post(Uri.parse(url), headers: {
        'content-type': 'application/json; charset=utf-8',
        'accept': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 12));
      return _decode(response);
    } on http.ClientException {
      throw const AuthException('Cannot connect to backend server.');
    } catch (e) {
      if (e is AuthException || e is MonitoringUnavailableException) rethrow;
      developer.log('Monitoring POST failed: $e', name: 'RelocationMonitoring');
      throw AuthException(e.toString());
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode == 404) {
      throw const MonitoringUnavailableException();
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    final detail = json['detail'];
    throw AuthException(detail is String ? detail : 'Request failed');
  }
}

/// Thrown when the backend has no monitoring routes for this hive yet.
class MonitoringUnavailableException implements Exception {
  const MonitoringUnavailableException();

  @override
  String toString() =>
      'Post-relocation monitoring is not available on the server yet.';
}

enum CameraConnection { connected, connecting, disconnected }

/// Activity states reported by the computer-vision backend.
enum ActivityLevel { monitoring, low, typical, unusual, insufficientData }

DateTime? _parseDate(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class MonitoringStatus {
  final CameraConnection camera;
  final bool monitoringActive;
  final DateTime? monitoringStartedAt;
  final DateTime? monitoringStoppedAt;
  final DateTime? relocatedAt;
  final String? deviceId;

  const MonitoringStatus({
    required this.camera,
    required this.monitoringActive,
    this.monitoringStartedAt,
    this.monitoringStoppedAt,
    this.relocatedAt,
    this.deviceId,
  });

  factory MonitoringStatus.fromJson(Map<String, dynamic> json) {
    final cam = (json['camera_status'] ?? '').toString().toLowerCase();
    return MonitoringStatus(
      camera: switch (cam) {
        'connected' || 'online' => CameraConnection.connected,
        'connecting' => CameraConnection.connecting,
        _ => CameraConnection.disconnected,
      },
      monitoringActive: json['monitoring_active'] == true,
      monitoringStartedAt: _parseDate(json['monitoring_started_at']),
      monitoringStoppedAt: _parseDate(json['monitoring_stopped_at']),
      relocatedAt: _parseDate(json['relocated_at']),
      deviceId: json['device_id']?.toString(),
    );
  }
}

class ActivityReading {
  final DateTime timestamp;
  final double movementsPerMinute;

  const ActivityReading(this.timestamp, this.movementsPerMinute);

  static ActivityReading? tryParse(dynamic e) {
    if (e is! Map) return null;
    final ts = _parseDate(e['timestamp']);
    final v = e['movements_per_minute'];
    if (ts == null || v is! num) return null;
    return ActivityReading(ts, v.toDouble());
  }
}

class ActivitySnapshot {
  final List<ActivityReading> readings;

  /// Calculated by the backend analysis; null when no analysis exists.
  final ActivityLevel? activityLevel;
  final double? latestMovementsPerMinute;
  final DateTime? lastReadingAt;
  final String? observationSummary;

  const ActivitySnapshot({
    required this.readings,
    this.activityLevel,
    this.latestMovementsPerMinute,
    this.lastReadingAt,
    this.observationSummary,
  });

  factory ActivitySnapshot.fromJson(Map<String, dynamic> json) {
    final readings = (json['readings'] as List<dynamic>? ?? [])
        .map(ActivityReading.tryParse)
        .whereType<ActivityReading>()
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final level = (json['activity_level'] ?? '').toString().toLowerCase();
    final latest = json['latest_movements_per_minute'];
    final summary = json['observation_summary']?.toString().trim();
    return ActivitySnapshot(
      readings: readings,
      activityLevel: switch (level) {
        'monitoring' => ActivityLevel.monitoring,
        'low' || 'low_activity' => ActivityLevel.low,
        'typical' || 'typical_activity' => ActivityLevel.typical,
        'unusual' || 'unusual_activity' => ActivityLevel.unusual,
        'insufficient_data' => ActivityLevel.insufficientData,
        _ => null,
      },
      latestMovementsPerMinute: latest is num ? latest.toDouble() : null,
      lastReadingAt: _parseDate(json['last_reading_at']) ??
          (readings.isNotEmpty ? readings.last.timestamp : null),
      observationSummary:
          (summary == null || summary.isEmpty) ? null : summary,
    );
  }
}

// ── Bee detection (trained YOLOv8n model on the backend) ──────────────

class BeeDetectionException implements Exception {
  final String message;
  const BeeDetectionException(this.message);

  @override
  String toString() => message;
}

class BeeDetection {
  final double confidence;

  /// [x1, y1, x2, y2] as fractions (0–1) of the analysed image size.
  final List<double> bboxNormalized;

  const BeeDetection(this.confidence, this.bboxNormalized);

  static BeeDetection? tryParse(dynamic e) {
    if (e is! Map) return null;
    final c = e['confidence'];
    final box = e['bbox_normalized'];
    if (c is! num || box is! List || box.length != 4) return null;
    if (box.any((v) => v is! num)) return null;
    return BeeDetection(
        c.toDouble(), box.map((v) => (v as num).toDouble()).toList());
  }
}

class BeeDetectionResult {
  final int beeCount;
  final List<BeeDetection> detections;
  final double? maxConfidence;
  final double? meanConfidence;
  final int imageWidth;
  final int imageHeight;

  /// JPEG of the exact (orientation-corrected) image the model analysed.
  final Uint8List? processedImage;
  final double confidenceThreshold;
  final String modelName;
  final double? inferenceMs;
  final DateTime? analyzedAt;
  final List<String> limitations;

  const BeeDetectionResult({
    required this.beeCount,
    required this.detections,
    required this.maxConfidence,
    required this.meanConfidence,
    required this.imageWidth,
    required this.imageHeight,
    required this.processedImage,
    required this.confidenceThreshold,
    required this.modelName,
    required this.inferenceMs,
    required this.analyzedAt,
    required this.limitations,
  });

  bool get hasBees => beeCount > 0;

  factory BeeDetectionResult.fromJson(Map<String, dynamic> json) {
    final detections = (json['detections'] as List<dynamic>? ?? [])
        .map(BeeDetection.tryParse)
        .whereType<BeeDetection>()
        .toList();
    final summary = json['confidence_summary'];
    final image = json['image'];
    final model = json['model'];

    Uint8List? processed;
    final dataUrl = json['processed_image'];
    if (dataUrl is String && dataUrl.contains(',')) {
      try {
        processed = base64Decode(dataUrl.split(',').last);
      } catch (_) {}
    }

    double? num2d(dynamic v) => v is num ? v.toDouble() : null;

    return BeeDetectionResult(
      beeCount: (json['bee_count'] as num?)?.toInt() ?? detections.length,
      detections: detections,
      maxConfidence: summary is Map ? num2d(summary['max']) : null,
      meanConfidence: summary is Map ? num2d(summary['mean']) : null,
      imageWidth: image is Map ? (image['width'] as num?)?.toInt() ?? 0 : 0,
      imageHeight: image is Map ? (image['height'] as num?)?.toInt() ?? 0 : 0,
      processedImage: processed,
      confidenceThreshold:
          model is Map ? num2d(model['confidence_threshold']) ?? 0 : 0,
      modelName: model is Map ? model['name']?.toString() ?? '' : '',
      inferenceMs: num2d(json['inference_ms']),
      analyzedAt: _parseDate(json['analyzed_at']),
      limitations: (json['limitations'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
