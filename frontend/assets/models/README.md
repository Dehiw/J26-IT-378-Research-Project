# Model assets go here (mirrors the reference project's assets/models/):
#
#   hive_model.onnx          — hive-health classifier (input [1,3,224,224], ImageNet norm)
#   feature_extractor.onnx   — penultimate-layer feature extractor (for OOD scoring)
#   labels.json              — class names (already present)
#   ood_config.json          — {"ood_threshold": ..., "class_means": ..., "precision_matrix": ...}
#
# Export these from your training notebook, drop them in this folder,
# then run `flutter pub get` and restart the app. Until then the app
# runs in demo mode (scan UI works, analysis shows a notice).
