from pathlib import Path
from ultralytics import YOLO

BASE = Path(__file__).resolve().parent

model = YOLO(
    str(BASE / "runs" / "bee_detection_test" / "weights" / "best.pt")
)

# Use one image from the test dataset
images = list((BASE / "dataset" / "images" / "test").glob("*.jpg"))

if not images:
    raise FileNotFoundError("No test images found.")

results = model.predict(
    source=str(images[0]),
    conf=0.25,
    save=True,
    project=str(BASE / "runs"),
    name="bee_prediction",
    exist_ok=True,
)

print("Prediction completed!")
print("Image:", images[0].name)
print("Bees detected:", len(results[0].boxes))