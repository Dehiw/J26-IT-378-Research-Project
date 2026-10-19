import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../utils/api_config.dart';
import 'auth_service.dart';

/// Service for submitting and retrieving Wild Bee Hive Reports.
/// Connects to the FastAPI backend and Firestore database.
class WildBeeService {
  static final WildBeeService instance = WildBeeService._internal();
  WildBeeService._internal();

  /// Submits a wild bee hive report to the backend (saved into Firestore).
  Future<Map<String, dynamic>> submitReport({
    required String address,
    required String gpsCoordinates,
    required String colonyLocation,
    required String height,
    required String insideStructure,
    required String safeAccess,
    bool hasPhoto = false,
    String? photoUrl,
    String? notes,
    String? assignedBeekeeper,
    String? assignedPhone,
    String? assignedBeekeeperId,
  }) async {
    final endpoint = '${ApiConfig.baseUrl}/wild-bee-reports';
    final payload = {
      'address': address.trim(),
      'gps_coordinates': gpsCoordinates.trim(),
      'colony_location': colonyLocation,
      'height': height,
      'inside_structure': insideStructure,
      'safe_access': safeAccess,
      'has_photo': hasPhoto,
      'photo_url': photoUrl,
      'notes': notes,
      'assigned_beekeeper': assignedBeekeeper,
      'assigned_phone': assignedPhone,
      'assigned_beekeeper_id': assignedBeekeeperId,
    };

    developer.log('Submitting wild bee report to backend: $endpoint',
        name: 'WildBeeService');

    try {
      final res = await _postJson(endpoint, payload);
      developer.log('Report saved in database: ${res['report_id']}',
          name: 'WildBeeService');
      return res;
    } catch (e) {
      developer.log('Error submitting report to database: $e',
          name: 'WildBeeService');
      rethrow;
    }
  }

  /// Fetches reports submitted by the current user.
  Future<List<Map<String, dynamic>>> fetchMyReports() async {
    final endpoint = '${ApiConfig.baseUrl}/wild-bee-reports/my';
    try {
      final res = await _getJson(endpoint);
      final list = (res['reports'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      return list;
    } catch (e) {
      developer.log('Error fetching user reports: $e', name: 'WildBeeService');
      return [];
    }
  }

  /// Fetches ALL wild bee hive reports (for beekeepers to review & manage).
  Future<List<Map<String, dynamic>>> fetchAllReports() async {
    final endpoint = '${ApiConfig.baseUrl}/wild-bee-reports/all';
    try {
      final res = await _getJson(endpoint);
      final list = (res['reports'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      return list;
    } catch (e) {
      developer.log('Error fetching all reports: $e', name: 'WildBeeService');
      return [];
    }
  }

  /// Detects real-world location (coordinates and city/area) via IP-geolocation.
  /// Works reliably across Web, Android, and Windows Desktop without native plugin failures.
  Future<Map<String, String>?> detectCurrentLocation() async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final uri = Uri.parse('http://ip-api.com/json');
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (data['status'] == 'success') {
        final double lat = (data['lat'] as num).toDouble();
        final double lon = (data['lon'] as num).toDouble();
        final String city = data['city']?.toString() ?? 'Colombo';
        final String region = data['regionName']?.toString() ?? 'Western';
        final String country = data['country']?.toString() ?? 'Sri Lanka';

        final latDir = lat >= 0 ? 'N' : 'S';
        final lonDir = lon >= 0 ? 'E' : 'W';
        final coords =
            '${lat.abs().toStringAsFixed(4)}° $latDir, ${lon.abs().toStringAsFixed(4)}° $lonDir';

        return {
          'coordinates': coords,
          'address': '$city, $region, $country',
          'city': city,
          'lat': lat.toString(),
          'lon': lon.toString(),
        };
      }
    } catch (e) {
      developer.log('IP location detection notice: $e', name: 'WildBeeService');
    } finally {
      client?.close();
    }
    return null;
  }

  // ── Native HTTP Helpers ─────────────────────────────────────

  Future<Map<String, dynamic>> _postJson(
      String url, Map<String, dynamic> body) async {
    final token = AuthService.instance.token;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 14);
      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('content-type', 'application/json; charset=utf-8');
      request.headers.set('accept', 'application/json');
      if (token != null) {
        request.headers.set('authorization', 'Bearer $token');
      }
      final bytes = utf8.encode(jsonEncode(body));
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close();
      final respBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(respBody) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json;
      }
      final detail = json['detail'];
      if (detail is String) throw AuthException(detail);
      throw AuthException(json['message']?.toString() ?? 'Request failed');
    } on SocketException {
      throw const AuthException(
          'Cannot connect to backend server. Make sure the FastAPI backend is running.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    } finally {
      client?.close();
    }
  }

  /// Cancels a submitted report if relocation has not started.
  Future<bool> cancelReport(String reportId) async {
    final endpoint = '${ApiConfig.baseUrl}/wild-bee-reports/$reportId/cancel';
    try {
      await _patchJson(endpoint, {});
      return true;
    } catch (e) {
      developer.log('Error cancelling report: $e', name: 'WildBeeService');
      rethrow;
    }
  }

  /// Assigns a selected beekeeper to a report.
  Future<Map<String, dynamic>> assignBeekeeper({
    required String reportId,
    required String beekeeperName,
    String? beekeeperPhone,
    String? beekeeperId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/wild-bee-reports/$reportId/assign-beekeeper').replace(
      queryParameters: {
        'beekeeper_name': beekeeperName,
        if (beekeeperPhone != null && beekeeperPhone.isNotEmpty)
          'beekeeper_phone': beekeeperPhone,
        if (beekeeperId != null && beekeeperId.isNotEmpty)
          'beekeeper_id': beekeeperId,
      },
    );
    try {
      return await _patchJson(uri.toString(), {});
    } catch (e) {
      developer.log('Error assigning beekeeper: $e', name: 'WildBeeService');
      rethrow;
    }
  }

  /// Updates relocation lifecycle fields in Firestore
  /// (status, schedule date/time, notes, completion photos).
  Future<Map<String, dynamic>> manageReport({
    required String reportId,
    required Map<String, dynamic> updates,
  }) async {
    final endpoint = '${ApiConfig.baseUrl}/wild-bee-reports/$reportId/manage';
    try {
      return await _patchJson(endpoint, updates);
    } catch (e) {
      developer.log('Error managing report $reportId: $e', name: 'WildBeeService');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _patchJson(
      String url, Map<String, dynamic> body) async {
    final token = AuthService.instance.token;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 14);
      final request = await client.patchUrl(Uri.parse(url));
      request.headers.set('content-type', 'application/json; charset=utf-8');
      request.headers.set('accept', 'application/json');
      if (token != null) {
        request.headers.set('authorization', 'Bearer $token');
      }
      final bytes = utf8.encode(jsonEncode(body));
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close();
      final respBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(respBody) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json;
      }
      final detail = json['detail'];
      if (detail is String) throw AuthException(detail);
      throw AuthException(json['message']?.toString() ?? 'Request failed');
    } on SocketException {
      throw const AuthException(
          'Cannot connect to backend server. Make sure the FastAPI backend is running.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    } finally {
      client?.close();
    }
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final token = AuthService.instance.token;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 14);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('accept', 'application/json');
      if (token != null) {
        request.headers.set('authorization', 'Bearer $token');
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) return json;
      throw AuthException(json['detail']?.toString() ?? 'Request failed');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    } finally {
      client?.close();
    }
  }
}
