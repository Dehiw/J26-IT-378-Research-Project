import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Backend API base URL.
  /// For a physical device, set API_BASE_URL at run time, e.g.
  /// --dart-define=API_BASE_URL=http://192.168.1.20:8000/api/v1
  /// Android emulators use 10.0.2.2; web, desktop, and iOS simulators use localhost.
  static String get baseUrl {
    if (_override.trim().isNotEmpty) {
      return _override.trim().replaceFirst(RegExp(r'/+$'), '');
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }
}
