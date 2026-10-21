import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../utils/api_config.dart';
import 'auth_service.dart';

class ImageInferenceApi {
  final http.Client? client;
  final String? tokenOverride;

  const ImageInferenceApi({this.client, this.tokenOverride});

  Future<Map<String, dynamic>> analyze({
    XFile? outsideImage,
    XFile? insideImage,
    String? location,
    String? hiveId,
  }) async {
    if (outsideImage == null && insideImage == null) {
      throw const ImageInferenceException('Choose at least one image.');
    }
    final token = tokenOverride ?? AuthService.instance.accessToken;
    if (token == null || token.isEmpty) {
      throw const ImageInferenceException('Sign in to analyze images.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/inference/analyze'),
    )..headers['authorization'] = 'Bearer $token';
    if (location != null && location.trim().isNotEmpty) {
      request.fields['q'] = location.trim();
    }
    if (hiveId != null) request.fields['hive_id'] = hiveId;
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
        throw ImageInferenceException(
          detail?.toString() ?? 'Image analysis failed.',
        );
      }
      if (payload is! Map<String, dynamic>) {
        throw const ImageInferenceException(
          'The server returned an unexpected response.',
        );
      }
      return payload;
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

  Future<http.MultipartFile> _imagePart(String field, XFile image) async {
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
