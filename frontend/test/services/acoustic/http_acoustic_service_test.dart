import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/models/acoustic/acoustic_result.dart';
import 'package:frontend/services/acoustic/acoustic_service.dart';
import 'package:frontend/services/acoustic/http_acoustic_service.dart';

Map<String, Object?> _json({String label = 'normal', bool saved = false}) => {
  'id': 'r1',
  'hive_id': 'h1',
  'label': label,
  'confidence': 0.82,
  'audio_quality': 'good',
  'model_version': 'queen_baseline_rf_v1',
  'analyzed_at': '2026-10-20T08:00:00+00:00',
  'clip_count': 2,
  'clip_probabilities': [0.8, 0.9],
  'source': 'upload',
  'saved': saved,
};

HttpAcousticService _service(MockClient client) => HttpAcousticService(
  hivesProvider: () async => const [],
  client: client,
  tokenProvider: () => 'tok',
  baseUrl: 'http://x/api/v1',
);

http.Response _reply(Object body, int code) => http.Response(
  jsonEncode(body),
  code,
  headers: {'content-type': 'application/json'},
);

void main() {
  final wav = Uint8List.fromList([1, 2, 3, 4]);

  test('analyzeAudio sends the file with auth and parses the result', () async {
    late http.BaseRequest seen;
    final service = _service(
      MockClient.streaming((request, body) async {
        seen = request;
        final bytes = await body.toBytes();
        final text = utf8.decode(bytes, allowMalformed: true);
        expect(text, contains('name="hive_id"'));
        expect(text, contains('h1'));
        expect(text, contains('name="source"'));
        expect(text, contains('name="audio"'));
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(_json()))),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final result = await service.analyzeAudio(
      hiveId: 'h1',
      bytes: wav,
      filename: 'a.wav',
    );
    expect(seen.url.toString(), 'http://x/api/v1/acoustic/analyze');
    expect(seen.headers['authorization'], 'Bearer tok');
    expect(result.label, AcousticLabel.normal);
    expect(result.confidence, closeTo(0.82, 1e-9));
    expect(service.isDemo, isFalse);
  });

  test('503 shows the backend message, not a fake result', () async {
    final service = _service(
      MockClient(
        (_) async => _reply({'detail': 'Acoustic model not available'}, 503),
      ),
    );
    expect(
      service.analyzeAudio(hiveId: 'h1', bytes: wav, filename: 'a.wav'),
      throwsA(
        isA<AcousticException>().having(
          (e) => e.message,
          'message',
          'Acoustic model not available',
        ),
      ),
    );
  });

  test('backend down gives a clear message', () async {
    final service = _service(
      MockClient((_) async => throw http.ClientException('refused')),
    );
    expect(
      service.getHistory(),
      throwsA(
        isA<AcousticException>().having(
          (e) => e.message,
          'message',
          contains('Cannot reach the server'),
        ),
      ),
    );
  });

  test('saveResult posts to the save endpoint, history parses results', () async {
    final urls = <String>[];
    final service = _service(
      MockClient((request) async {
        urls.add('${request.method} ${request.url}');
        if (request.url.path.endsWith('/history')) {
          return _reply({
            'results': [_json(label: 'queenless', saved: true)],
          }, 200);
        }
        return _reply(_json(saved: true), 200);
      }),
    );
    final r = (await service.getHistory(hiveId: 'h1')).single;
    expect(r.label, AcousticLabel.queenless);
    await service.saveResult(r);
    expect(urls, [
      'GET http://x/api/v1/acoustic/history?hive_id=h1',
      'POST http://x/api/v1/acoustic/results/r1/save',
    ]);
  });
}
