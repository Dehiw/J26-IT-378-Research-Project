import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/api_config.dart';
import 'auth_service.dart';

class ColonyAssessmentApi {
  const ColonyAssessmentApi();

  Future<Map<String, dynamic>> fetch({String? location, String? hiveId}) async {
    final token = AuthService.instance.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Sign in to load colony monitoring.');
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/environment/assessment')
        .replace(
          queryParameters: {
            if (location != null && location.trim().isNotEmpty)
              'q': location.trim(),
            'hive_id': ?hiveId,
          },
        );
    final response = await http
        .get(uri, headers: {'authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 30));
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(payload['detail'] ?? 'Colony monitoring is unavailable.');
    }
    return payload;
  }
}
