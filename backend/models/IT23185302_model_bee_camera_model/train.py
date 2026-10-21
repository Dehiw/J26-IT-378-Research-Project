
from pathlib import Path
from ultralytics import YOLO

BASE_DIR = Path(__file__).resolve().parent
DATA_YAML = BASE_DIR / "dataset" / "data.yaml"

if not DATA_YAML.exists():
    raise FileNotFoundError(f"Dataset configuration not found: {DATA_YAML}")

# Small pretrained YOLOv8 model
model = YOLO("yolov8n.pt")

# Initial training test
results = model.train(
    data=str(DATA_YAML),
    epochs=2,
    imgsz=416,
    batch=4,
    device="cpu",
    workers=0,
    project=str(BASE_DIR / "runs"),
    name="bee_detection_test",
    exist_ok=False,
    plots=True,
)

print("Training test completed!")
