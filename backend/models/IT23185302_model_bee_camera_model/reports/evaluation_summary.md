# Bee Detection Model — Evaluation Summary

## Research Component

IT23185302 — Post-Relocation Bee Entrance Monitoring

## Model

- Architecture: YOLOv8n
- Framework: Ultralytics
- Training device: CPU
- Training epochs: 2
- Training image size: 416
- Batch size: 4

## Dataset

Labeled Dataset for Bee Detection and Direction Estimation
on Beehive Landing Boards — Mendeley Data.

Dataset URL:
https://data.mendeley.com/datasets/8gb9r2yhfc/6

## Dataset Preparation

| Split      | Images |
| ---------- | -----: |
| Train      |   5288 |
| Validation |    856 |
| Test       |    514 |
| Total      |   6658 |

542 images without matching label files were excluded
from this experiment.

## Validation Results

| Metric    | Value |
| --------- | ----: |
| Precision | 0.807 |
| Recall    | 0.588 |
| mAP@50    | 0.688 |
| mAP@50-95 | 0.342 |

## Test Results

| Metric    |  Value |
| --------- | -----: |
| Precision | 0.8976 |
| Recall    | 0.7098 |
| mAP@50    | 0.8482 |
| mAP@50-95 | 0.4978 |

Test set:

- Images: 514
- Annotated bee instances: 1206

## Interpretation

The initial YOLOv8n model demonstrates promising
bee detection performance on the selected test recording.

However, recall indicates that some annotated bees
are missed, and bounding-box localization can improve.

These results do not measure bee tracking accuracy,
entering/exiting counts, or relocation success.

## Limitations

- Only two training epochs were completed.
- The dataset originates from recorded beehive entrances.
- No ESP32-CAM field validation has been completed.
- Missing-label images were excluded.
- Generalization to Sri Lankan apiaries is not yet verified.

## Future Improvements

- Improve model training.
- Evaluate different hive entrance recordings.
- Implement bee movement tracking.
- Estimate entrance and exit counts.
- Test using ESP32-CAM footage.
- Validate results against beekeeper observations.
