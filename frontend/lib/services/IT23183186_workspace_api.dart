import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/api_config.dart';
import 'auth_service.dart';
import 'environment_fallback.dart';

class ColonyWorkspaceApi {
  final http.Client? client;
  final String? tokenOverride;
  const ColonyWorkspaceApi({this.client, this.tokenOverride});
  Future<Map<String, dynamic>> load(String hiveId) =>
      request(hiveId, 'workspace');
  Future<Map<String, dynamic>> observe(
    String hiveId,
    Map<String, dynamic> data,
  ) => request(hiveId, 'observations', method: 'POST', data: data);
  Future<Map<String, dynamic>> plan(String hiveId, Map<String, dynamic> data) =>
      request(hiveId, 'care-plans', method: 'POST', data: data);
  Future<Map<String, dynamic>> complete(String hiveId, String planId) =>
      request(
        hiveId,
        'care-plans/${Uri.encodeComponent(planId)}/complete',
        method: 'POST',
      );
  Future<Map<String, dynamic>> review(String hiveId, String key) =>
      request(hiveId, 'alert-reviews', method: 'POST', data: {'key': key});
  Future<Map<String, dynamic>> preferences(
    String hiveId,
    Map<String, dynamic> data,
  ) => request(hiveId, 'preferences', method: 'PUT', data: data);
  Future<Map<String, dynamic>> request(
    String hiveId,
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    final token = tokenOverride ?? AuthService.instance.accessToken;
    final store = EnvironmentFallback.instance;
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/environment/hives/${Uri.encodeComponent(hiveId)}/$path',
    );
    if (method == 'GET') {
      final result = await store.request(
        'workspace/$hiveId',
        uri,
        'workspace',
        client: client,
        token: token,
        authenticated: true,
        demoOnly: isDemoId(hiveId),
      );
      if (dataSource(result) == 'demo') return store.workspaceDemo(hiveId);
      final monitor = result['monitoring'];
      if (monitor is Map && monitor['sensor'] == null) {
        final demo = await store.fixture('monitoring');
        monitor['sensor'] = demo['sensor'];
        result['sensor_history'] = [demo['sensor']];
        result['sensor_error'] = null;
        store.markSource('workspace-sensor/$hiveId', 'demo');
      } else {
        store.markSource('workspace-sensor/$hiveId', 'live');
      }
      return store.mergeWorkspace(result, hiveId);
    }
    if (!isDemoId(hiveId) &&
        !path.split('/').any(isDemoId) &&
        !isDemoId(data?['key']?.toString())) {
      final transport = client ?? http.Client();
      try {
        if (token == null) {
          throw const EnvironmentRequestFailure('Sign in before saving.', 401);
        }
        final request = http.Request(method, uri)
          ..headers.addAll({
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          });
        if (data != null) request.body = jsonEncode(data);
        final response = await http.Response.fromStream(
          await transport.send(request),
        ).timeout(const Duration(seconds: 25));
        if (response.statusCode >= 400) {
          throw EnvironmentRequestFailure(
            'This change could not be saved.',
            response.statusCode,
          );
        }
        return store.tagged(jsonDecode(response.body) as Map, 'live');
      } catch (e) {
        if (e is EnvironmentRequestFailure && !e.permitsFallback) rethrow;
      } finally {
        if (client == null) transport.close();
      }
    }
    final kind = path == 'observations'
        ? 'observations'
        : path.startsWith('care-plans')
        ? 'care_plans'
        : path == 'alert-reviews'
        ? 'alert_reviews'
        : 'preferences';
    final record = await store.saveLocal(hiveId, {
      ...data ?? {},
      'action_path': path,
      if (path.endsWith('/complete')) 'target_id': path.split('/')[1],
      'status': path.endsWith('/complete') ? 'completed' : 'planned',
    }, kind: kind);
    return {...record, 'record': record, 'observation': record, 'plan': record};
  }
}
