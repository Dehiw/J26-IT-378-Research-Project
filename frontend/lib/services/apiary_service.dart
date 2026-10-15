import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/apiary_model.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';

/// Service for managing Apiaries and Hive Boxes.
/// All operations call the FastAPI backend and cache results locally.
class ApiaryService {
  static final ApiaryService instance = ApiaryService._internal();
  ApiaryService._internal();

  // Local cache
  List<ApiaryModel> _apiaries = [];
  ApiaryModel? _selectedApiary;

  List<ApiaryModel> get apiaries => List.unmodifiable(_apiaries);
  ApiaryModel? get selectedApiary => _selectedApiary;

  static const _keySelectedApiary = 'selected_apiary_id';

  // ── Apiary Operations ──────────────────────────────────────────

  /// Fetch all apiaries for current user from backend
  Future<List<ApiaryModel>> fetchApiaries() async {
    try {
      final res = await _getJson('${ApiConfig.baseUrl}/apiary/list');
      final list = (res['apiaries'] as List<dynamic>? ?? [])
          .map((e) => ApiaryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _apiaries = list;

      // Restore or default selected apiary
      await _restoreSelectedApiary();
      developer.log('Fetched ${_apiaries.length} apiaries', name: 'ApiaryService');
      return List<ApiaryModel>.from(_apiaries);
    } catch (e) {
      developer.log('Failed to fetch apiaries: $e', name: 'ApiaryService');
      rethrow;
    }
  }

  /// Create a new apiary location
  Future<ApiaryModel> createApiary({
    required String locationName,
    required String areaAddress,
    String? gpsLocation,
  }) async {
    final payload = {
      'location_name': locationName.trim(),
      'area_address': areaAddress.trim(),
      'gps_location': gpsLocation?.trim(),
    };
    final res = await _postJson('${ApiConfig.baseUrl}/apiary/create', payload);
    final apiary = ApiaryModel.fromJson(res['apiary'] as Map<String, dynamic>);
    _apiaries.add(apiary);
    // Auto-select if first apiary
    if (_apiaries.length == 1) {
      await selectApiary(apiary);
    }
    return apiary;
  }

  /// Set the currently selected apiary (persisted to SharedPreferences)
  Future<void> selectApiary(ApiaryModel apiary) async {
    _selectedApiary = apiary;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedApiary, apiary.id);
    developer.log('Selected apiary: ${apiary.locationName}', name: 'ApiaryService');
  }

  // ── Hive Box Operations ────────────────────────────────────────

  /// Fetch all hive boxes for a specific apiary
  Future<List<HiveModel>> fetchHives(String apiaryId) async {
    try {
      final res = await _getJson('${ApiConfig.baseUrl}/apiary/$apiaryId/hives');
      final list = (res['hives'] as List<dynamic>? ?? [])
          .map((e) => HiveModel.fromJson(e as Map<String, dynamic>))
          .toList();
      developer.log('Fetched ${list.length} hives for apiary $apiaryId', name: 'ApiaryService');
      return list;
    } catch (e) {
      developer.log('Failed to fetch hives: $e', name: 'ApiaryService');
      rethrow;
    }
  }

  /// Create a new hive box under an apiary
  Future<HiveModel> createHive({
    required String apiaryId,
    required String hiveName,
    required int numFrames,
    required String hiveType,
    required String beeSpecies,
    String? installationDate,
  }) async {
    final payload = {
      'apiary_id': apiaryId,
      'hive_name': hiveName.trim(),
      'num_frames': numFrames,
      'hive_type': hiveType,
      'bee_species': beeSpecies,
      if (installationDate != null) 'installation_date': installationDate,
    };
    final res = await _postJson('${ApiConfig.baseUrl}/apiary/hive/create', payload);
    return HiveModel.fromJson(res['hive'] as Map<String, dynamic>);
  }

  /// Get the next suggested hive box number/name for a given apiary
  Future<String> getNextHiveSuggestion(String apiaryId) async {
    try {
      final res = await _getJson(
          '${ApiConfig.baseUrl}/apiary/$apiaryId/next-hive-number');
      return res['suggested_name'] as String? ?? 'Hive Box #01';
    } catch (_) {
      return 'Hive Box #01';
    }
  }

  // ── Internal ───────────────────────────────────────────────────

  Future<void> _restoreSelectedApiary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_keySelectedApiary);
      if (savedId != null) {
        _selectedApiary = _apiaries.firstWhere(
          (a) => a.id == savedId,
          orElse: () => _apiaries.isNotEmpty ? _apiaries.first : _selectedApiary!,
        );
      } else if (_apiaries.isNotEmpty) {
        _selectedApiary = _apiaries.first;
      }
    } catch (_) {
      if (_apiaries.isNotEmpty) _selectedApiary = _apiaries.first;
    }
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final token = AuthService.instance.token;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
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

  Future<Map<String, dynamic>> _postJson(
      String url, Map<String, dynamic> body) async {
    final token = AuthService.instance.token;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
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
      if (response.statusCode >= 200 && response.statusCode < 300) return json;
      final detail = json['detail'];
      if (detail is String) throw AuthException(detail);
      throw AuthException(json['message']?.toString() ?? 'Request failed');
    } on SocketException {
      throw const AuthException('Cannot connect to backend server.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    } finally {
      client?.close();
    }
  }
}
