import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../utils/api_config.dart';
import 'auth_service.dart';
import 'environment_fallback.dart';

class ImageInferenceApi {
  final http.Client? client;
  final String? tokenOverride;

  const ImageInferenceApi({this.client, this.tokenOverride});

  Future<Map<String, dynamic>> analyze({
    XFile? outsideImage,
    XFile? insideImage,
    String? location,
    String? hiveId,
    bool saveResult = false,
  }) async {
    if (outsideImage == null && insideImage == null) {
      throw const ImageInferenceException('Choose at least one image.');
    }
    if (outsideImage != null) await validateImage(outsideImage);
    if (insideImage != null) await validateImage(insideImage);
    final store = EnvironmentFallback.instance;
    final result = await store.read(
      'image-analysis',
      () => _analyzeLive(
        outsideImage: outsideImage,
        insideImage: insideImage,
        location: location,
        hiveId: isDemoId(hiveId) ? null : hiveId,
        saveResult: saveResult && !isDemoId(hiveId),
      ),
      'image_analysis',
      preferCache: false,
    );
    Map<String, dynamic>? demo;
    for (final key in ['model_a', 'model_b']) {
      final submitted = key == 'model_a'
          ? outsideImage != null
          : insideImage != null;
      if (!submitted) {
        result[key] = null;
        continue;
      }
      final part = result[key];
      if (part is! Map ||
          part['status'] == 'unavailable' ||
          part['status'] == 'error') {
        demo ??= await store.fixture('image_analysis');
        result[key] = demo[key];
        store.markSource(key, 'demo');
      } else {
        store.markSource(key, dataSource(part));
      }
    }
    if (saveResult &&
        (dataSource(result) == 'demo' ||
            isDemoId(hiveId) ||
            result['save_error'] != null)) {
      final record = await store.saveLocal(hiveId ?? 'demo-hive-1', {
        ...result,
        'record_type': 'image_assessment',
      }, origin: dataSource(result));
      result.remove('saved_record_id');
      result['local_saved_record_id'] = record['id'];
    }
    return result;
  }

  Future<Map<String, dynamic>> _analyzeLive({
    XFile? outsideImage,
    XFile? insideImage,
    String? location,
    String? hiveId,
    bool saveResult = false,
  }) async {
    if (outsideImage == null && insideImage == null) {
      throw const ImageInferenceException('Choose at least one image.');
    }
    final token = tokenOverride ?? AuthService.instance.accessToken;
    if (token == null || token.isEmpty) {
      throw const EnvironmentRequestFailure('Sign in to analyze images.', 401);
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/inference/analyze'),
    )..headers['authorization'] = 'Bearer $token';
    if (location != null && location.trim().isNotEmpty) {
      request.fields['q'] = location.trim();
    }
    if (hiveId != null) request.fields['hive_id'] = hiveId;
    if (saveResult) request.fields['save_result'] = 'true';
    if (outsideImage != null) {
      request.files.add(await _imagePart('outside_image', outsideImage));
    }
    if (insideImage != null) {
      request.files.add(await _imagePart('inside_image', insideImage));
    }

    final transport = client ?? http.Client();
    try {
      final streamed = await transport
          .send(request)
          .timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);
      final payload = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = payload is Map ? payload['detail'] : null;
        throw EnvironmentRequestFailure(
          detail?.toString() ?? 'Image analysis failed.',
          response.statusCode,
        );
      }
      if (payload is! Map<String, dynamic> ||
          (outsideImage != null && payload['model_a'] is! Map) ||
          (insideImage != null && payload['model_b'] is! Map)) {
        throw const ImageInferenceException(
          'The server returned an unexpected response.',
        );
      }
      return payload;
    } on EnvironmentRequestFailure {
      rethrow;
    } on ImageInferenceException {
      rethrow;
    } catch (_) {
      throw const ImageInferenceException(
        'Could not reach the image analysis service. Check the backend connection.',
      );
    } finally {
      if (client == null) transport.close();
    }
  }

  Future<Map<String, dynamic>> fetchModelReport(String modelKey) =>
      EnvironmentFallback.instance.request(
        'model-report/$modelKey',
        Uri.parse('${ApiConfig.baseUrl}/inference/reports/$modelKey'),
        'model_report',
        client: client,
        token: tokenOverride ?? AuthService.instance.accessToken,
        authenticated: true,
      );

  static Future<void> validateImage(XFile image) async {
    final size = await image.length();
    if (size == 0) {
      throw const ImageInferenceException('The selected image is empty.');
    }
    if (size > 10 * 1024 * 1024) {
      throw const ImageInferenceException(
        'Each image must be 10 MB or smaller.',
      );
    }
    final bytes = await image.readAsBytes();
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    final png =
        bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
    final webp =
        bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
    if (!jpeg && !png && !webp) {
      throw const ImageInferenceException('Use a JPEG, PNG, or WebP image.');
    }
  }

  Future<http.MultipartFile> _imagePart(String field, XFile image) async {
    await validateImage(image);
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw const ImageInferenceException('The selected image is empty.');
    }
    if (bytes.length > 10 * 1024 * 1024) {
      throw const ImageInferenceException(
        'Each image must be 10 MB or smaller.',
      );
    }
    final name = image.name.isEmpty ? '$field.jpg' : image.name;
    return http.MultipartFile.fromBytes(field, bytes, filename: name);
  }
}

class ImageInferenceException implements Exception {
  final String message;
  const ImageInferenceException(this.message);
  @override
  String toString() => message;
}
