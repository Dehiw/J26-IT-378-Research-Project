import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:frontend/services/image_inference_api.dart';

const _liveToken = String.fromEnvironment('HIVE_SENSE_TEST_TOKEN');

void main() {
  test(
    'Flutter multipart request reaches FastAPI and receives separate model statuses',
    () async {
      final source = img.Image(width: 4, height: 4);
      img.fill(source, color: img.ColorRgb8(120, 140, 160));
      final png = Uint8List.fromList(img.encodePng(source));
      final result = await const ImageInferenceApi(tokenOverride: _liveToken)
          .analyze(
            outsideImage: XFile.fromData(png, name: 'bee.png'),
            insideImage: XFile.fromData(png, name: 'frame.png'),
          );

      expect(result['model_a']['status'], 'unavailable');
      expect(result['model_b']['status'], 'unavailable');
    },
    skip: _liveToken.isEmpty
        ? 'Set HIVE_SENSE_TEST_TOKEN to run against a live local FastAPI server.'
        : false,
  );
}
