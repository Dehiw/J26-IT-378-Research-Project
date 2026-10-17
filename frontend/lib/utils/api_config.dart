import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Default base URL for backend connection.
  /// Android Emulator accesses host localhost via 10.0.2.2.
  /// iOS Simulator / Desktop / Web accesses host localhost directly.
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }
}
