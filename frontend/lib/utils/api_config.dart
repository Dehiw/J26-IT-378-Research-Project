import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Backend API base URL.
  /// Android emulators use 10.0.2.2 to reach the host machine's localhost.
  /// Web, desktop, and iOS simulators use localhost directly.
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }
}
