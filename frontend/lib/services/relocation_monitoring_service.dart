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
