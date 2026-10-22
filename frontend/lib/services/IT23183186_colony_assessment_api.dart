import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/api_config.dart';
import 'auth_service.dart';
import 'environment_fallback.dart';

class ColonyAssessmentApi {
  final http.Client? client;
  final String? tokenOverride;
  const ColonyAssessmentApi({this.client, this.tokenOverride});
  String? get _token => tokenOverride ?? AuthService.instance.accessToken;
  Uri _uri(String path, {String? location}) =>
      Uri.parse('${ApiConfig.baseUrl}/environment/$path').replace(
        queryParameters: {
          if (location != null && location.trim().isNotEmpty) 'q': location,
        },
      );
  Future<Map<String, dynamic>> fetch({String? location, String? hiveId}) async {
    final uri = _uri('assessment', location: location).replace(
      queryParameters: {
        if (location != null && location.trim().isNotEmpty) 'q': location,
        if (hiveId != null && !isDemoId(hiveId)) 'hive_id': hiveId,
      },
    );
    final data = await EnvironmentFallback.instance.request(
      'assessment/$hiveId/$location',
      uri,
      'monitoring',
      client: client,
      token: _token,
      authenticated: true,
    );
    if (data['assessment'] is! Map) {
      throw const EnvironmentRequestFailure('Monitoring could not be read.');
    }
    // A successful partial assessment remains actual. Only absent providers use demo examples.
    if (dataSource(data) != 'demo' &&
        (data['weather'] == null || data['sensor'] == null)) {
      final demo = await EnvironmentFallback.instance.fixture('monitoring');
      if (data['weather'] == null) {
        data['weather'] = demo['weather'];
        data['environment'] = demo['environment'];
      }
      if (data['sensor'] == null) data['sensor'] = demo['sensor'];
      EnvironmentFallback.instance.markSource('sensor/$hiveId', 'demo');
    }
    EnvironmentFallback.instance.markSource(
      'sensor/$hiveId',
      dataSource(data['sensor'] as Map?),
    );
    return data;
  }

  Future<Map<String, dynamic>> saveSnapshot({
    required String hiveId,
    String? location,
  }) async {
    if (!isDemoId(hiveId)) {
      final transport = client ?? http.Client();
      try {
        if (_token == null) {
          throw const EnvironmentRequestFailure('Sign in before saving.', 401);
        }
        final response = await transport
            .post(
              _uri(
                'hives/${Uri.encodeComponent(hiveId)}/records',
                location: location,
              ),
              headers: {'authorization': 'Bearer $_token'},
            )
            .timeout(const Duration(seconds: 25));
        if (response.statusCode >= 400) {
          throw EnvironmentRequestFailure(
            'This snapshot could not be saved.',
            response.statusCode,
          );
        }
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        return EnvironmentFallback.instance.tagged(
          payload['record'] as Map,
          'live',
        );
      } catch (e) {
        if (e is EnvironmentRequestFailure && !e.permitsFallback) rethrow;
      } finally {
        if (client == null) transport.close();
      }
    }
    final demo = await EnvironmentFallback.instance.fixture('monitoring');
    return EnvironmentFallback.instance.saveLocal(hiveId, {
      ...demo,
      'record_type': 'environment_assessment',
      'location_query': 'Demo apiary, Kandy',
      'real_save_completed': false,
    });
  }

  Future<List<Map<String, dynamic>>> fetchHistory(String hiveId) async {
    final data = await EnvironmentFallback.instance.request(
      'history/$hiveId',
      _uri('hives/${Uri.encodeComponent(hiveId)}/records'),
      'environment_history',
      client: client,
      token: _token,
      authenticated: true,
      demoOnly: isDemoId(hiveId),
    );
    return [
      ...await EnvironmentFallback.instance.localRecords(hiveId),
      ...(data['records'] as List? ?? []).whereType<Map>().map(
        (r) => Map<String, dynamic>.from(r),
      ),
    ];
  }
}
