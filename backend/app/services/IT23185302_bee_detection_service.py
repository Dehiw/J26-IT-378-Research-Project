"""IT23185302 bee detection service (post-relocation camera monitoring).

Serves the trained single-class YOLOv8n bee detector from
backend/models/IT23185302_model_bee_camera_model. The model is loaded once per
process at application startup; every request reuses it.

The same ``detect`` entry point is used for manually uploaded images today and
is intended for ESP32-CAM frames later (``source="esp32cam"``). Camera capture
and streaming are not implemented here.

Configuration (optional environment variables):
    BEE_DETECTION_WEIGHTS     path to the trained weights (default: runs/.../best.pt)
    BEE_DETECTION_CONFIDENCE  minimum box confidence, default 0.25 (as in predict.py)
    BEE_DETECTION_IMGSZ       inference image size, default 416 (training size)
"""

from __future__ import annotations

import base64
import io
import logging
import os
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

from PIL import Image, ImageOps, UnidentifiedImageError

logger = logging.getLogger(__name__)

BACKEND_DIR = Path(__file__).resolve().parents[2]
MODEL_DIR = BACKEND_DIR / "models" / "IT23185302_model_bee_camera_model"
DEFAULT_WEIGHTS = MODEL_DIR / "runs" / "bee_detection_test" / "weights" / "best.pt"
EXPECTED_CLASSES = {0: "bee"}
MODEL_NAME = "IT23185302 YOLOv8n bee detector"

MAX_IMAGE_BYTES = 10 * 1024 * 1024
ALLOWED_IMAGE_FORMATS = {"JPEG", "PNG", "WEBP"}
MAX_PIXELS = 40_000_000
PREVIEW_MAX_EDGE = 1280

LIMITATIONS = [
    "Prototype model trained for 2 epochs on landing-board images; counts can be "
    "too high or too low, especially for small, overlapping, or partly visible bees.",
    "The count covers bees visible in this single image only; it is not a colony "
    "population estimate or an entrance/exit count.",
    "Not yet validated on ESP32-CAM footage or local Sri Lankan colonies.",
]


def _env_float(name: str, default: float) -> float:
    try:
        return float(os.getenv(name) or default)
    except ValueError:
        return default


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name) or default)
    except ValueError:
        return default


def decode_bee_image(data: bytes) -> Image.Image:
    """Validate and decode an upload, applying EXIF rotation so box
    coordinates match the image the user sees."""
    if not data:
        raise ValueError("The uploaded image is empty.")
    try:
        with Image.open(io.BytesIO(data)) as source:
            if source.format not in ALLOWED_IMAGE_FORMATS:
                raise ValueError("Use a JPEG, PNG, or WebP image.")
            if source.width * source.height > MAX_PIXELS:
                raise ValueError("Image dimensions are too large to process.")
            source.verify()
        with Image.open(io.BytesIO(data)) as source:
            image = ImageOps.exif_transpose(source).convert("RGB")
            image.load()
            return image
    except (UnidentifiedImageError, Image.DecompressionBombError, OSError) as exc:
        raise ValueError("The uploaded image could not be decoded.") from exc


def encode_preview(image: Image.Image) -> str:
    """JPEG data URL of the analysed image (downscaled for transfer)."""
    preview = image.copy()
    preview.thumbnail((PREVIEW_MAX_EDGE, PREVIEW_MAX_EDGE))
    buffer = io.BytesIO()
    preview.save(buffer, format="JPEG", quality=85)
    return "data:image/jpeg;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


class BeeDetectionService:
    def __init__(self) -> None:
        self.model: Any = None
        self._load_attempted = False
        self._lock = threading.Lock()
        self.confidence = _env_float("BEE_DETECTION_CONFIDENCE", 0.25)
        self.image_size = _env_int("BEE_DETECTION_IMGSZ", 416)
        self.status: dict[str, Any] = {
            "available": False,
            "message": "The bee detection model has not been loaded.",
        }

    def load_once(self) -> None:
        """Load the trained weights once per application process."""
        if self._load_attempted:
            return
        self._load_attempted = True

        path = Path(os.getenv("BEE_DETECTION_WEIGHTS") or DEFAULT_WEIGHTS)
        if not path.is_file():
            self.status = {
                "available": False,
                "message": "Trained bee detection weights (best.pt) are not installed on the server.",
            }
            return
        try:
            from ultralytics import YOLO

            model = YOLO(str(path))
            names = dict(model.names) if isinstance(model.names, dict) else dict(enumerate(model.names))
            if model.task != "detect" or names != EXPECTED_CLASSES:
                raise ValueError(f"Unexpected model task/classes: {model.task} {names}")
            self.model = model
            self.status = {"available": True, "message": "Bee detection model is ready."}
        except Exception as exc:
            logger.warning("IT23185302 bee detection model failed to load: %s", exc)
            self.status = {
                "available": False,
                "message": "The bee detection model could not be loaded. Check the weights and inference dependencies.",
            }

    def describe(self) -> dict[str, Any]:
        return {
            "name": MODEL_NAME,
            "classes": list(EXPECTED_CLASSES.values()),
            "confidence_threshold": self.confidence,
            "image_size": self.image_size,
        }

    def detect(
        self,
        image: Image.Image,
        source: str = "upload",
        hive_id: Optional[str] = None,
    ) -> dict[str, Any]:
        if self.model is None:
            raise RuntimeError("Bee detection model is not available.")

        started = time.perf_counter()
        with self._lock:  # one inference at a time on the shared model
            result = self.model.predict(
                image, conf=self.confidence, imgsz=self.image_size, verbose=False
            )[0]
        inference_ms = (time.perf_counter() - started) * 1000

        width, height = image.size
        detections = []
        if result.boxes is not None and len(result.boxes):
            for box, confidence, class_id in zip(
                result.boxes.xyxy.cpu().tolist(),
                result.boxes.conf.cpu().tolist(),
                result.boxes.cls.cpu().tolist(),
            ):
                if int(class_id) not in EXPECTED_CLASSES:
                    continue
                x1, y1, x2, y2 = (float(v) for v in box)
                detections.append({
                    "class_name": EXPECTED_CLASSES[int(class_id)],
                    "confidence": round(float(confidence), 4),
                    "bbox_xyxy": [round(x1, 1), round(y1, 1), round(x2, 1), round(y2, 1)],
                    "bbox_normalized": [
                        round(x1 / width, 5),
                        round(y1 / height, 5),
                        round(x2 / width, 5),
                        round(y2 / height, 5),
                    ],
                })
        detections.sort(key=lambda d: d["confidence"], reverse=True)

        confidences = [d["confidence"] for d in detections]
        summary = None
        if confidences:
            summary = {
                "max": max(confidences),
                "mean": round(sum(confidences) / len(confidences), 4),
                "min": min(confidences),
            }

        return {
            "status": "bees_detected" if detections else "no_bees_detected",
            "bee_count": len(detections),
            "detections": detections,
            "confidence_summary": summary,
            "image": {"width": width, "height": height},
            "processed_image": encode_preview(image),
            "source": source,
            "hive_id": hive_id,
            "model": self.describe(),
            "inference_ms": round(inference_ms, 1),
            "analyzed_at": datetime.now(timezone.utc).isoformat(),
            "limitations": LIMITATIONS,
        }
