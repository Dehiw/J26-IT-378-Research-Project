# IT23185302 — Bee Camera Detection Model

## 1. Overview

This module is part of the final-year research project:

AI-Based Smart Beehive Mobile Platform for Colony
Health Monitoring and Relocation Support.

Component: IT23185302

The model detects individual honeybees near the
entrance of a beehive using YOLOv8 object detection.

The detection model will support the development
of a post-relocation bee entrance monitoring system.

## 2. Research Objective

To detect bees near the hive entrance and support
the estimation of bee entrance activity following
colony relocation.

## 3. Technologies

- Python 3.13
- Ultralytics YOLOv8n
- PyTorch
- OpenCV
- Visual Studio Code
- FastAPI (planned integration)
- ESP32-CAM (planned integration)
- Flutter (mobile application)

## 4. Dataset

Name:
Labeled Dataset for Bee Detection and Direction
Estimation on Beehive Landing Boards.

Source: Mendeley Data

https://data.mendeley.com/datasets/8gb9r2yhfc/6

The dataset contains annotated beehive entrance
images suitable for bee object detection.

## 5. Dataset Preparation

Original images: 7200

Prepared images: 6658

Train: 5288
Validation: 856
Test: 514

Missing-label images excluded: 542

The original recording folders were split between
training, validation and testing to reduce leakage
between closely related video frames.

## 6. Model Architecture

YOLOv8n (YOLOv8 Nano)

The model uses pretrained weights and is fine-tuned
for a single object detection class:

Class 0: Bee

## 7. Model Training

Initial experiment configuration:

- Epochs: 2
- Image size: 416
- Batch size: 4
- Device: CPU
- Optimizer: Ultralytics default configuration

Run the initial training experiment:

    python train.py

## 8. Model Evaluation

Evaluate the trained model:

    python evaluate.py

Initial held-out test results:

- Precision: 89.76%
- Recall: 70.98%
- mAP@50: 84.82%
- mAP@50-95: 49.78%

These results are from the initial two-epoch model
and are not final research evaluation results.

## 9. Prediction

Run a sample bee detection prediction:

    python predict.py

The prediction script loads the trained best.pt
weights and tests an image from the test dataset.

## 10. Model Outputs

The current model provides:

- Bee bounding boxes
- Detection confidence
- Detected bee count per image

The following are planned, not yet implemented:

- Bee movement tracking
- Entrance and exit counting
- Movement activity history
- Post-relocation activity comparisons
- ESP32-CAM live monitoring

## 11. Limitations

- No real ESP32-CAM footage has been evaluated.
- The current model does not classify relocation
  as successful or unsuccessful.
- Bee entrance traffic alone cannot establish
  overall colony health or successful adaptation.
- Some images lacked matching annotation files.
- Model performance on local Sri Lankan bee
  colonies remains unverified.

## 12. Future Development

1. Implement YOLO and ByteTrack tracking.
2. Estimate bee entrance and exit events.
3. Compare activity measurements over time.
4. Connect the ESP32-CAM video stream.
5. Integrate the monitoring results with FastAPI.
6. Display monitoring results in Flutter.
7. Validate activity estimates against manually
   counted events and beekeeper observations.

## 13. Project File Structure

IT23185302_model_bee_camera_model/
dataset/
runs/
reports/
inspect_dataset.py
prepare_dataset.py
train.py
evaluate.py
predict.py
requirements.txt
README.md

## 14. Research Status

Completed:

- Dataset inspection
- Dataset preprocessing
- Initial YOLO training
- Validation and held-out test evaluation
- Sample image inference

Pending:

- Tracking and direction estimation
- Entrance activity monitoring
- Camera integration
- Field validation
