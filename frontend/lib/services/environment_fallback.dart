import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

const sourceKey = '_data_source';
String dataSource(Map? data) => data?[sourceKey]?.toString() ?? 'live';
bool isDemoId(String? id) => id?.startsWith('demo-') == true;

class EnvironmentRequestFailure implements Exception {
  final int? status;
  final String message;
  const EnvironmentRequestFailure(this.message, [this.status]);
  bool get permitsFallback =>
      status == null || status! >= 500 || status == 408 || status == 429;
  @override
  String toString() => message;
}

/// One policy for live reads, account-scoped actual caches, and isolated demos.
/// Every read tries the real service again; fallback never becomes a sticky mode.
class EnvironmentFallback extends ChangeNotifier {
  static final instance = EnvironmentFallback();
  EnvironmentFallback({this.scopeOverride, this.fixtureLoader});
  final String? scopeOverride;
  final Future<Map<String, dynamic>> Function()? fixtureLoader;
  final Map<String, Map<String, dynamic>> _cache = {};
  final Map<String, String> sources = {};
  Future<Map<String, dynamic>>? _fixtures;
  String get scope =>
      scopeOverride ?? AuthService.instance.currentUser?.id ?? 'guest';
  String _key(String key) => '$scope::$key';
  bool get needsRecovery => sources.entries.any(
    (e) =>
        e.key.startsWith('$scope::') &&
        (e.value == 'demo' || e.value == 'cached'),
  );
  String sourceFor(String key) => sources[_key(key)] ?? 'live';
  void _track(String key, String source) {
    sources[_key(key)] = source;
    notifyListeners();
  }

  Map<String, dynamic> tagged(Map data, String source) {
    dynamic visit(dynamic value) {
      if (value is Map) {
        return <String, dynamic>{
          for (final e in value.entries) e.key.toString(): visit(e.value),
          sourceKey: source,
        };
      }
      if (value is List) return value.map(visit).toList();
      return value;
    }

    return visit(data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fixture(String name) async {
    _fixtures ??= fixtureLoader != null
        ? fixtureLoader!()
        : rootBundle
              .loadString('assets/demo/environment_disease_demo.json')
              .then((s) => jsonDecode(s) as Map<String, dynamic>);
    final all = await _fixtures!;
    return tagged(jsonDecode(jsonEncode(all[name])) as Map, 'demo');
  }

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      developer.log(
        'Local demonstration storage unavailable: ${e.runtimeType}',
        name: 'EnvironmentFallback',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>> read(
    String key,
    Future<Map<String, dynamic>> Function() live,
    String demo, {
    bool preferCache = true,
    bool demoOnly = false,
  }) async {
    final accountKey = _key(key);
    try {
      if (demoOnly) throw const EnvironmentRequestFailure('Local demo context');
      final raw = await live();
      if (!_valid(demo, raw)) {
        throw const FormatException('Incomplete service response');
      }
      final data = tagged(raw, 'live');
      data['_retrieved_at'] = DateTime.now().toUtc().toIso8601String();
      _cache[accountKey] = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
      unawaited(_persistActual(accountKey, data));
      _track(key, 'live');
      return data;
    } catch (error, stack) {
      if (error is EnvironmentRequestFailure && !error.permitsFallback) rethrow;
      developer.log(
        'Read failed for $key (${error.runtimeType}); using labelled fallback.',
        name: 'EnvironmentFallback',
        stackTrace: stack,
      );
      Map<String, dynamic>? cached = _cache[accountKey];
      if (cached == null && preferCache && !demoOnly) {
        final raw = (await _prefs())?.getString(
          'environment_actual_v1::$accountKey',
        );
        try {
          if (raw != null) cached = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          cached = null;
        }
      }
      if (preferCache && cached != null && !demoOnly) {
        _track(key, 'cached');
        return tagged(cached, 'cached');
      }
      final value = await fixture(demo);
      _track(key, 'demo');
      return value;
    }
  }

  Future<void> _persistActual(
    String accountKey,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await _prefs();
      final encoded = jsonEncode(data);
      if (encoded.length < 2000000) {
        await prefs?.setString('environment_actual_v1::$accountKey', encoded);
      }
    } catch (_) {
      developer.log(
        'Actual response retained; local caching failed.',
        name: 'EnvironmentFallback',
      );
    }
  }

  bool _valid(String fixture, Map data) {
    bool weather(Map? w) =>
        w?['location'] is Map &&
        w?['current'] is Map &&
        (w!['current'] as Map)['temperature_c'] is num &&
        (w['current'] as Map)['humidity_percent'] is num;
    switch (fixture) {
      case 'weather':
        return weather(data);
      case 'impact':
        return weather(data['weather'] as Map?) && data['analysis'] is Map;
      case 'forecast':
        return data['days'] is List;
      case 'weather_history':
        return data['days'] is List;
      case 'monitoring':
        return data['assessment'] is Map;
      case 'workspace':
        return data['records'] is List && data['preferences'] is Map;
      case 'model_report':
        return data['summary'] is Map && data['history'] is List;
      case 'environment_history':
        return data['records'] is List;
      default:
        return true;
    }
  }

  Future<Map<String, dynamic>> request(
    String key,
    Uri uri,
    String demo, {
    http.Client? client,
    String? token,
    String method = 'GET',
    Map<String, dynamic>? body,
    bool authenticated = false,
    bool demoOnly = false,
  }) async {
    return read(
      key,
      () async {
        if (authenticated && (token == null || token.isEmpty)) {
          throw const EnvironmentRequestFailure(
            'Sign in to access your records.',
            401,
          );
        }
        final transport = client ?? http.Client();
        try {
          final request = http.Request(method, uri)
            ..headers['content-type'] = 'application/json';
          if (token != null) request.headers['authorization'] = 'Bearer $token';
          if (body != null) request.body = jsonEncode(body);
          final response = await http.Response.fromStream(
            await transport.send(request),
          ).timeout(const Duration(seconds: 18));
          if (response.statusCode >= 400) {
            throw EnvironmentRequestFailure(
              response.statusCode >= 500 ? 'Service temporarily unavailable.' : 'This request could not be completed. Check your access and inputs.',
              response.statusCode,
            );
          }
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('Expected an object');
          }
          return decoded;
        } finally {
          if (client == null) transport.close();
        }
      },
      demo,
      demoOnly: demoOnly,
    );
  }

  Future<List<Map<String, dynamic>>> localRecords(
    String hiveId, {
    String kind = 'records',
  }) async {
    final raw = (await _prefs())?.getString(
      'environment_demo_v1::${_key('$hiveId/$kind')}',
    );
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> saveLocal(
    String hiveId,
    Map data, {
    String kind = 'records',
    String origin = 'demo',
  }) async {
    final records = await localRecords(hiveId, kind: kind);
    final dedupe = jsonEncode(data);
    if (kind == 'records') {
      for (final existing in records) {
        if (existing['_dedupe'] == dedupe) return existing;
      }
    }
    final record = tagged({
      ...data,
      'id': 'demo-local-${DateTime.now().microsecondsSinceEpoch}',
      'hive_id': hiveId,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'persistence': origin == 'demo' ? 'local_demo' : 'local_preview',
      'local_only': true,
      '_dedupe': dedupe,
    }, origin);
    records.insert(0, record);
    final prefs = await _prefs();
    if (prefs == null ||
        !await prefs.setString(
          'environment_demo_v1::${_key('$hiveId/$kind')}',
          jsonEncode(records.take(50).toList()),
        )) {
      throw const EnvironmentRequestFailure(
        'Could not save this demo on the device.',
        400,
      );
    }
    return record;
  }

  Future<Map<String, dynamic>> workspaceDemo(String hiveId) async =>
      mergeWorkspace(await fixture('workspace'), hiveId);
  Future<Map<String, dynamic>> mergeWorkspace(
    Map<String, dynamic> data,
    String hiveId,
  ) async {
    data['records'] = [
      ...await localRecords(hiveId),
      ...data['records'] as List? ?? [],
    ];
    for (final kind in ['observations', 'care_plans', 'alert_reviews']) {
      final local = await localRecords(hiveId, kind: kind);
      final base = (data[kind] as List? ?? []).whereType<Map>().toList();
      final updates = {
        for (final r in local)
          if (r['target_id'] != null) r['target_id'].toString(): r,
      };
      final merged = <Map>[...local.where((r) => r['target_id'] == null)];
      for (final original in base) {
        final update = updates[original['id']];
        if (update != null && dataSource(original) == 'demo') {
          merged.add({...original, ...update, 'id': original['id']});
        } else {
          if (update != null) {
            merged.add({...original, ...update, 'target_id': original['id']});
          }
          merged.add(original);
        }
      }
      data[kind] = merged;
    }
    final preferences = await localRecords(hiveId, kind: 'preferences');
    if (preferences.isNotEmpty) {
      data['preferences'] = {
        ...data['preferences'] as Map? ?? {},
        ...preferences.first,
      };
    }
    return data;
  }

  Future<void> selectDemo({String? apiaryId, String? hiveId}) async {
    final prefs = await _prefs();
    final key = 'environment_demo_selection_v1::$scope';
    Map<String, dynamic> current = {};
    try {
      current =
          jsonDecode(prefs?.getString(key) ?? '{}') as Map<String, dynamic>;
    } catch (_) {
      // A damaged local selection must not prevent choosing another demo hive.
    }
    if (apiaryId != null) current['apiary_id'] = apiaryId;
    if (hiveId != null) current['hive_id'] = hiveId;
    await prefs?.setString(key, jsonEncode(current));
  }

  Future<String?> selectedDemoHive() async {
    final raw = (await _prefs())?.getString(
      'environment_demo_selection_v1::$scope',
    );
    try {
      return raw == null
          ? null
          : (jsonDecode(raw) as Map)['hive_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  void markSource(String key, String source) => _track(key, source);
  void clearSession() {
    _cache.clear();
    sources.clear();
  }
}
