// The onnxruntime package is built on dart:ffi, which does not exist in a
// web browser. Pick the real implementation on Android/iOS and a stub on web
// so the app still builds and opens in demo mode with `flutter run -d chrome`.
export 'prediction_result.dart';
export 'inference_service_native.dart'
    if (dart.library.js_interop) 'inference_service_web.dart';
