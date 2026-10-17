import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../utils/api_config.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  static const String _keyToken = 'auth_jwt_token';
  static const String _keyUser = 'auth_user_data';

  UserModel? _currentUser;
  String? _token;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  /// Restores saved session from SharedPreferences on app start
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_keyToken);
      final userJsonStr = prefs.getString(_keyUser);

      if (_token != null && userJsonStr != null) {
        final Map<String, dynamic> userMap = jsonDecode(userJsonStr);
        _currentUser = UserModel.fromJson(userMap, token: _token);
        developer.log('Restored session for ${_currentUser?.email}',
            name: 'AuthService');
        return true;
      }
    } catch (e) {
      developer.log('Failed to restore auth session: $e', name: 'AuthService');
    }
    return false;
  }

  /// Sends register request to FastAPI backend
  /// Sends register request to FastAPI backend
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final endpoint = '${ApiConfig.baseUrl}/auth/register';
    final payload = {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    };

    final responseMap = await _postJson(endpoint, payload);
    final userMap = responseMap['user'] as Map<String, dynamic>;
    final accessToken = responseMap['access_token'] as String;

    _token = accessToken;
    _currentUser = UserModel.fromJson(userMap, token: accessToken);

    await _persistSession(_token!, _currentUser!);
    return _currentUser!;
  }

  /// Sends login request to FastAPI backend
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final endpoint = '${ApiConfig.baseUrl}/auth/login';
    final payload = {
      'email': email.trim().toLowerCase(),
      'password': password,
    };

    final responseMap = await _postJson(endpoint, payload);
    final userMap = responseMap['user'] as Map<String, dynamic>;
    final accessToken = responseMap['access_token'] as String;

    _token = accessToken;
    _currentUser = UserModel.fromJson(userMap, token: accessToken);

    await _persistSession(_token!, _currentUser!);
    return _currentUser!;
  }

  /// Checks whether the current user has completed first-time setup
  Future<bool> hasCompletedSetup() async {
    if (_currentUser == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getBool('setup_completed_${_currentUser!.id}');
    if (cached != null) return cached;

    if (_token != null) {
      try {
        final statusRes = await _getJson('${ApiConfig.baseUrl}/apiary/status',
            token: _token);
        final completed = statusRes['setup_completed'] as bool? ?? false;
        await prefs.setBool('setup_completed_${_currentUser!.id}', completed);
        return completed;
      } catch (_) {}
    }
    return false;
  }

  /// Saves the 3-step first-time apiary setup to the backend
  Future<void> saveApiarySetup({
    required String locationName,
    required String areaAddress,
    String? gpsLocation,
    required String hiveName,
    required String hiveType,
    required String beeSpecies,
    required int numFrames,
  }) async {
    final payload = {
      'location_name': locationName.trim(),
      'area_address': areaAddress.trim(),
      'gps_location': gpsLocation?.trim(),
      'hive_name': hiveName.trim(),
      'hive_type': hiveType,
      'bee_species': beeSpecies,
      'num_frames': numFrames,
    };

    await _postJson('${ApiConfig.baseUrl}/apiary/setup', payload,
        token: _token);

    if (_currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('setup_completed_${_currentUser!.id}', true);
    }
  }

  /// Fetches next suggested box name (e.g. Hive Box #01, Hive Box #02)
  Future<String> getNextHiveSuggestion() async {
    if (_token != null) {
      try {
        final res = await _getJson('${ApiConfig.baseUrl}/apiary/next-hive-number',
            token: _token);
        return res['suggested_name'] as String? ?? 'Hive Box #01';
      } catch (_) {}
    }
    return 'Hive Box #01';
  }

  /// Clears stored token and logs the user out
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUser);
      developer.log('User logged out', name: 'AuthService');
    } catch (e) {
      developer.log('Error clearing session: $e', name: 'AuthService');
    }
  }

  Future<void> _persistSession(String token, UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
      await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    } catch (e) {
      developer.log('Failed to persist session: $e', name: 'AuthService');
    }
  }

  /// Native HTTP GET request
  Future<Map<String, dynamic>> _getJson(String url, {String? token}) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'accept': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 30));
      final responseBody = response.body;
      final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonResponse;
      }
      throw AuthException(
          jsonResponse['detail']?.toString() ?? 'Request failed');
    } on http.ClientException {
      throw const AuthException(
          'Cannot connect to backend server. Make sure the FastAPI server is running.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    }
  }

  /// Native HTTP POST request using dart:io HttpClient
  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final response = await http.post(Uri.parse(url),
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'accept': 'application/json',
            if (token != null) 'authorization': 'Bearer $token',
          },
          body: jsonEncode(body)).timeout(const Duration(seconds: 30));
      final responseBody = response.body;

      Map<String, dynamic> jsonResponse;
      try {
        jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
      } catch (_) {
        throw AuthException('Unexpected server response: $responseBody');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonResponse;
      } else {
        final detail = jsonResponse['detail'];
        if (detail is String) {
          throw AuthException(detail);
        } else if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          final msg = first is Map
              ? (first['msg'] ?? 'Validation error')
              : 'Validation error';
          throw AuthException(msg.toString());
        }
        throw AuthException(
            jsonResponse['message']?.toString() ?? 'Authentication failed');
      }
    } on http.ClientException catch (_) {
      throw const AuthException(
          'Cannot connect to backend server. Make sure the FastAPI server is running.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    }
  }
}
