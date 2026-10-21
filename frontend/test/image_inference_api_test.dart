import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/services/image_inference_api.dart';

void main() {
  const pngBytes = <int>[
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    0,
    0,
    0,
    13,
    73,
    72,
    68,
    82,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    1,
    8,
    6,
    0,
    0,
    0,
    31,
    21,
    196,
    137,
    0,
    0,
    0,
    13,
    73,
    68,
    65,
    84,
    8,
    215,
    99,
    248,
    207,
    192,
    240,
    31,
    0,
    5,
    0,
    1,
    255,
    137,
    153,
    61,
    29,
    0,
    0,
    0,
    0,
    73,
    69,
    78,
    68,
    174,
    66,
    96,
    130,
  ];

  test(
    'sends outside and inside images in separate multipart fields',
    () async {
      http.BaseRequest? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'model_a': {'status': 'complete'},
            'model_b': {'status': 'unavailable'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ImageInferenceApi(
        client: client,
        tokenOverride: 'test-token',
      );
      final result = await api.analyze(
        location: '6.9,79.8',
        hiveId: 'owned-hive',
        outsideImage: XFile.fromData(
          Uint8List.fromList(pngBytes),
          name: 'bee.png',
        ),
        insideImage: XFile.fromData(
          Uint8List.fromList(pngBytes),
          name: 'frame.png',
        ),
      );

      expect(result['model_a']['status'], 'complete');
      expect(captured?.headers['authorization'], 'Bearer test-token');
      final body = latin1.decode((captured as http.Request).bodyBytes);
      expect(body, contains('name="outside_image"'));
      expect(body, contains('name="inside_image"'));
      expect(body, contains('name="q"'));
      expect(body, contains('6.9,79.8'));
      expect(body, contains('name="hive_id"'));
      expect(body, contains('owned-hive'));
    },
  );

  test('rejects requests with no selected images', () async {
    final api = ImageInferenceApi(
      client: MockClient((_) async => http.Response('{}', 200)),
      tokenOverride: 'test-token',
    );
    expect(() => api.analyze(), throwsA(isA<ImageInferenceException>()));
  });
}
