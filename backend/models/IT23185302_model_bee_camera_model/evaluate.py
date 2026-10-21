
from pathlib import Path
from ultralytics import YOLO

BASE = Path(__file__).resolve().parent

MODEL_PATH = BASE / "runs" / "bee_detection_test" / "weights" / "best.pt"
DATA_PATH = BASE / "dataset" / "data.yaml"

if not MODEL_PATH.exists():
    raise FileNotFoundError(f"Model not found: {MODEL_PATH}")

if not DATA_PATH.exists():
    raise FileNotFoundError(f"Dataset not found: {DATA_PATH}")

# Load trained bee detection model
model = YOLO(str(MODEL_PATH))

# Evaluate on the independent test split
metrics = model.val(
    data=str(DATA_PATH),
    split="test",
    imgsz=416,
    batch=4,
    device="cpu",
    workers=0,
    project=str(BASE / "runs"),
    name="bee_test_evaluation",
    plots=True,
)

print("\n===== TEST EVALUATION RESULTS =====")
print(f"Precision: {metrics.box.mp:.4f}")
print(f"Recall: {metrics.box.mr:.4f}")
print(f"mAP50: {metrics.box.map50:.4f}")
print(f"mAP50-95: {metrics.box.map:.4f}")
