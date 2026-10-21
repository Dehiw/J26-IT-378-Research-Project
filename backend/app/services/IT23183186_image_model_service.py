"""Optional, startup-loaded Hive Sense image models.

Models are enabled only when their completed training artifacts are present.
The classifier's current partial checkpoint is deliberately not sufficient.
"""

from __future__ import annotations

import io
import os
from pathlib import Path
from typing import Any

from PIL import Image, UnidentifiedImageError


ROOT = Path(__file__).resolve().parents[3]
MODEL_A_DIR = ROOT / "backend" / "models" / "IT23183186_model_a_varroa_classifier"
MODEL_B_DIR = ROOT / "backend" / "models" / "IT23183186_model_b_hive_frame_detector"
MODEL_A_CLASSES = ["healthy", "varroa_positive"]
MODEL_B_CLASSES = [
    "CappedHoneyCell",
    "CappedWorkerBroodCell",
    "EmptyCombCell",
    "PollenCell",
    "UncappedNectarCell",
    "UncappedWorkerLarvaCell",
    "BeeHiveFrame",
]
MAX_IMAGE_BYTES = 10 * 1024 * 1024
ALLOWED_IMAGE_FORMATS = {"JPEG", "PNG", "WEBP"}


def decode_image(data: bytes) -> Image.Image:
    if not data:
        raise ValueError("The uploaded image is empty.")
    try:
        with Image.open(io.BytesIO(data)) as source:
            if source.format not in ALLOWED_IMAGE_FORMATS:
                raise ValueError("Use a JPEG, PNG, or WebP image.")
            if source.width * source.height > 40_000_000:
                raise ValueError("Image dimensions are too large to process.")
            source.verify()
        with Image.open(io.BytesIO(data)) as source:
            image = source.convert("RGB")
            image.load()
            return image
    except (UnidentifiedImageError, Image.DecompressionBombError, OSError) as exc:
        raise ValueError("The uploaded image could not be decoded.") from exc


class ImageModelService:
    def __init__(self) -> None:
        self.models: dict[str, Any] = {}
        self._load_attempted = False
        self.status: dict[str, dict[str, str | bool]] = {
            "model_a": {"available": False, "message": "A completed Model A checkpoint is not installed."},
            "model_b": {"available": False, "message": "A trained Model B checkpoint is not installed."},
        }

    def load_once(self) -> None:
        """Load each completed model once per application process."""
        if self._load_attempted:
            return
        self._load_attempted = True
        self._load_model_a()
        self._load_model_b()

    def _load_model_a(self) -> None:
        path = Path(os.getenv("HIVESENSE_MODEL_A_CHECKPOINT", str(MODEL_A_DIR / "artifacts" / "IT23183186_ModelA_MobileNetV2.pt")))
        metadata_paths = [path.parent / name for name in ("training_config.json", "preprocessing.json", "class_map.json")]
        if not path.is_file() or not all(item.is_file() for item in metadata_paths):
            self.status["model_a"] = {"available": False, "message": "Model A training is incomplete; a checkpoint with its training metadata is required."}
            return
        try:
            import json
            import torch
            from torchvision.models import mobilenet_v2
            from torch import nn

            class_map = json.loads(metadata_paths[2].read_text(encoding="utf-8"))
            if [class_map.get(str(i)) for i in range(2)] != MODEL_A_CLASSES:
                raise ValueError("Model A class map does not match the supported classes.")
            checkpoint = torch.load(path, map_location="cpu", weights_only=False)
            if checkpoint.get("class_names") != MODEL_A_CLASSES or "best_validation" not in checkpoint:
                raise ValueError("Model A checkpoint is not a completed supported checkpoint.")
            model = mobilenet_v2(weights=None)
            model.classifier[1] = nn.Linear(model.last_channel, len(MODEL_A_CLASSES))
            model.load_state_dict(checkpoint["model_state_dict"])
            model.eval()
            from torchvision.models import MobileNet_V2_Weights
            weights = MobileNet_V2_Weights.IMAGENET1K_V1
            preset = weights.transforms()
            self.models["model_a"] = {
                "model": model,
                "torch": torch,
                "mean": tuple(preset.mean),
                "std": tuple(preset.std),
                "threshold": float(checkpoint["best_validation"]["threshold"]),
                "version": "IT23183186_ModelA_MobileNetV2",
            }
            self.status["model_a"] = {"available": True, "message": "Model A is ready."}
        except Exception:
            self.status["model_a"] = {"available": False, "message": "Model A could not be loaded. Check its checkpoint and inference dependencies."}

    def _load_model_b(self) -> None:
        path = Path(os.getenv("HIVESENSE_MODEL_B_CHECKPOINT", str(MODEL_B_DIR / "runs" / "IT23183186_ModelB_YOLO11n" / "weights" / "best.pt")))
        if not path.is_file():
            self.status["model_b"] = {"available": False, "message": "Model B training is incomplete; its best checkpoint is not installed."}
            return
        try:
            from ultralytics import YOLO

            model = YOLO(str(path))
            names = model.names
            ordered = [names[i] if isinstance(names, dict) else names[i] for i in range(len(MODEL_B_CLASSES))]
            if ordered != MODEL_B_CLASSES:
                raise ValueError("Model B checkpoint classes do not match the verified FAIRHiveFrames classes.")
            self.models["model_b"] = {"model": model, "version": "IT23183186_ModelB_YOLO11n"}
            self.status["model_b"] = {"available": True, "message": "Model B is ready."}
        except Exception:
            self.status["model_b"] = {"available": False, "message": "Model B could not be loaded. Check its checkpoint and inference dependencies."}

    def predict_a(self, image: Image.Image) -> dict[str, Any]:
        if "model_a" not in self.models:
            raise RuntimeError("Model A is not available.")
        import torch
        from PIL import Image as PILImage

        loaded = self.models["model_a"]
        size = 224
        width, height = image.size
        scale = min(size / width, size / height)
        target = (max(1, min(size, round(width * scale))), max(1, min(size, round(height * scale))))
        resized = image.convert("RGB").resize(target, resample=PILImage.Resampling.BILINEAR)
        pad = tuple(round(channel * 255) for channel in loaded["mean"])
        canvas = PILImage.new("RGB", (size, size), color=pad)
        canvas.paste(resized, ((size - target[0]) // 2, (size - target[1]) // 2))
        tensor = torch.from_numpy(__import__("numpy").array(canvas, copy=True)).permute(2, 0, 1).float().div_(255.0)
        mean = torch.tensor(loaded["mean"]).view(3, 1, 1)
        std = torch.tensor(loaded["std"]).view(3, 1, 1)
        with torch.inference_mode():
            scores = torch.softmax(loaded["model"](((tensor - mean) / std).unsqueeze(0)), dim=1)[0].tolist()
        predicted = 1 if scores[1] >= loaded["threshold"] else 0
        return {
            "predicted_class": MODEL_A_CLASSES[predicted],
            "class_scores": {name: float(scores[i]) for i, name in enumerate(MODEL_A_CLASSES)},
            "model_version": loaded["version"],
            "limitations": [
                "Trained for VarroaDataset individual-bee crops, not whole-hive or frame images.",
                "A model score is not a disease probability or confirmed diagnosis.",
                "Performance on local field imagery has not been established.",
            ],
        }

    def predict_b(self, image: Image.Image) -> dict[str, Any]:
        if "model_b" not in self.models:
            raise RuntimeError("Model B is not available.")
        result = self.models["model_b"]["model"].predict(image, imgsz=640, verbose=False)[0]
        detections = []
        if result.boxes is not None:
            xyxy = result.boxes.xyxy.cpu().tolist()
            confidences = result.boxes.conf.cpu().tolist()
            classes = result.boxes.cls.cpu().tolist()
            for box, confidence, class_id in zip(xyxy, confidences, classes):
                detections.append({
                    "class_name": MODEL_B_CLASSES[int(class_id)],
                    "bbox_xyxy": [float(value) for value in box],
                    "confidence": float(confidence),
                })
        return {
            "detections": detections,
            "model_version": self.models["model_b"]["version"],
            "limitations": [
                "Classes describe comb and hive-frame structures; they are not disease labels.",
                "Detection confidence is not disease probability or a confirmed diagnosis.",
            ],
        }
