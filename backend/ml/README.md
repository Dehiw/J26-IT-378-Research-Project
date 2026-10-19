# Hive Sense image models

The research models are kept separate from the FastAPI and Flutter application code:

| Model | Task | Code | Data status |
|---|---|---|---|
| Model A | MobileNetV2 binary classification of individual bee crops: healthy / Varroa-positive | [model_a_varroa_classifier](model_a_varroa_classifier/README.md) | Official dataset inspected and prepared; run training locally to produce a completed model. |
| Model B | YOLO11n detection of seven FAIRHiveFrames comb/frame structures | [model_b_hive_frame_detector](model_b_hive_frame_detector/README.md) | Architecture and training/evaluation entry points are ready; the dataset archive must be supplied and its annotations checked before training. |

Neither model is connected to the app's current inference route by this work. Model B's seven structural labels do not represent disease classes. Both READMEs contain setup and run commands.
