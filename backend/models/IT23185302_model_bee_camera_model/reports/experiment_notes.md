# Experiment Notes — IT23185302

## Experiment 01 — Bee Detection

### Objective

Train a YOLOv8n model to identify individual bees
in images captured near beehive entrances.

### Dataset

Mendeley Bee Detection and Direction Estimation Dataset.

### Preprocessing

- Inspected 7200 images.
- Identified 542 images without matching labels.
- Prepared 6658 image-label pairs.
- Used recording-folder-based dataset splitting.
- Checked YOLO annotation format.

### Training

- Model: YOLOv8n
- Epochs: 2
- Device: CPU
- Image size: 416
- Batch size: 4

### Testing

- Evaluated on 514 test images.
- Achieved mAP@50 of 0.8482.
- Achieved recall of 0.7098.

### Observations

- The training pipeline works.
- The model detects bees in sample images.
- Detection performance requires further improvement.

### Next Experiment

Develop bee movement tracking using YOLO and ByteTrack.

### Pending

- ESP32-CAM integration.
- Real-world camera testing.
- Entrance/exit counting validation.
- Post-relocation monitoring evaluation.
