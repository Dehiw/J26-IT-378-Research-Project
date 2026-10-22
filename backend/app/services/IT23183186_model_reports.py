"""Read only artifacts belonging to the configured/loaded checkpoint; never infer test metrics from inference."""
from __future__ import annotations
import csv
import json
import math
import os
from pathlib import Path
from app.services.IT23183186_image_model_service import MODEL_A_DIR, MODEL_B_DIR

UNAVAILABLE = "Not available \u2014 evaluation results not found"

def checkpoint_path(key):
    if key == "model_a":
        return Path(os.getenv("HIVESENSE_MODEL_A_CHECKPOINT", str(MODEL_A_DIR / "artifacts" / "IT23183186_ModelA_MobileNetV2.pt"))).resolve()
    return Path(os.getenv("HIVESENSE_MODEL_B_CHECKPOINT", str(MODEL_B_DIR / "runs" / "IT23183186_ModelB_YOLO11n" / "weights" / "best.pt"))).resolve()

def _json(path):
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError, UnicodeError):
        return {}

def _number(value):
    try:
        result = float(value)
        return result if math.isfinite(result) else None
    except (ValueError, TypeError):
        return None

def _safe(value):
    # Never send training machine paths, manifest paths, or arbitrary configuration to clients.
    if isinstance(value, dict):
        return {k: _safe(v) for k, v in value.items() if k not in {"checkpoint", "test_manifest", "train_manifest", "validation_manifest", "dataset_yaml"}}
    if isinstance(value, list):
        return [_safe(v) for v in value]
    if isinstance(value, str) and (":\\" in value or value.startswith(("/", "\\"))):
        return "Local artifact (path omitted)"
    if isinstance(value, float) and not math.isfinite(value):
        return None
    return value

def model_report(key, checkpoint=None):
    path = Path(checkpoint).resolve() if checkpoint else checkpoint_path(key)
    run = path.parent if key == "model_a" else path.parent.parent
    config = _json(run / "training_config.json")
    detector_config = {}
    dataset_config = {}
    if key == "model_b":
        try:
            import yaml
            detector_config = yaml.safe_load((run / "args.yaml").read_text(encoding="utf-8")) or {}
            if not isinstance(detector_config, dict):
                detector_config = {}
            data_path = detector_config.get("data")
            if data_path and Path(data_path).is_file():
                dataset_config = yaml.safe_load(Path(data_path).read_text(encoding="utf-8")) or {}
                if not isinstance(dataset_config, dict):
                    dataset_config = {}
        except Exception:
            # Optional or malformed YAML must not make inference reports fail.
            detector_config = {}
            dataset_config = {}
    preprocessing = _json(run / "preprocessing.json")
    metadata = _json(run / "model_metadata.json")
    mapping = _json(run / "class_map.json")
    history = []
    history_path = run / ("training_history.csv" if key == "model_a" else "results.csv")
    try:
        with history_path.open(encoding="utf-8-sig", newline="") as stream:
            for index, raw in enumerate(csv.DictReader(stream)):
                if index >= 5000:
                    break
                row = {k.strip(): v for k, v in raw.items() if k}
                point = {"epoch": _number(row.get("epoch")), "phase": row.get("phase")}
                aliases = {"train_loss": ["train_loss", "train/box_loss"], "val_loss": ["val_loss", "val/box_loss"], "train_accuracy": ["train_accuracy", "train_acc"], "val_accuracy": ["val_accuracy", "val_acc"]}
                for field, names in aliases.items():
                    point[field] = next((_number(row[n]) for n in names if n in row), None)
                if point["epoch"] is not None:
                    history.append(point)
    except (OSError, csv.Error, UnicodeError):
        pass
    evaluation = None
    candidates = [run / "evaluation" / "test_evaluation.json", run / "test_evaluation.json"]
    if key == "model_b":
        candidates += sorted(run.parent.glob(run.name + "*_test*/test_evaluation.json"))
    for candidate in candidates:
        report = _json(candidate)
        # Require an explicit checkpoint identity and held-out split provenance.
        saved = report.get("checkpoint")
        is_test = report.get("split") == "test" or "test" in str(report.get("dataset", "")).lower()
        if not path.is_file() or not saved or Path(saved).resolve() != path or not is_test or report.get("test_set_used_for_model_selection") is True:
            continue
        allowed = {"accuracy", "per_class", "test_count", "dataset", "split", "evaluation_date", "evaluated_at", "confusion_matrix", "confusion_matrix_labels_order", "metrics", "interpretation_limit", "roc_auc", "test_set_used_for_model_selection"}
        evaluation = _safe({k: v for k, v in report.items() if k in allowed})
        evaluation.setdefault("split", "test")
        break
    if key == "model_b":
        names = dataset_config.get("names", {})
        if isinstance(names, list):
            mapping = {str(i): name for i, name in enumerate(names)}
        elif isinstance(names, dict):
            mapping = {str(i): name for i, name in names.items()}
        config = {**config, **{k: detector_config.get(k) for k in ("batch_size", "seed")}, "batch_size": detector_config.get("batch")}
        image_size = detector_config.get("imgsz")
        preprocessing = {**preprocessing, "architecture": Path(str(detector_config["model"])).name if detector_config.get("model") else None,
            "input_shape": [3, image_size, image_size] if isinstance(image_size, int) else image_size}
        if not metadata.get("dataset") and detector_config.get("data"):
            metadata["dataset"] = dataset_config.get("name") or Path(detector_config["data"]).stem
    dimensions = preprocessing.get("input_shape")
    summary = {
        "dataset": metadata.get("dataset"),
        "architecture": preprocessing.get("architecture"),
        "input_shape": dimensions,
        "class_mapping": mapping,
        "best_validation": config.get("best_validation"),
        "best_epoch": config.get("best_epoch"),
        "best_phase": config.get("best_phase"),
        "batch_size": config.get("batch_size"),
        "seed": config.get("seed"),
        "preprocessing": preprocessing.get("evaluation_transform"),
        "training_augmentation": preprocessing.get("training_only_augmentation"),
    }
    return {"model_key": key, "run_id": run.name, "checkpoint_identifier": path.name,
        "summary": _safe(summary), "history": history,
        "history_loss_label": "Box loss" if key == "model_b" else "Loss",
        "history_status": "available" if history else "unavailable",
        "history_help": "Run Model A train.py with --output-dir to save training_history.csv alongside the checkpoint." if key == "model_a" else "Run Model B train.py to save results.csv in the YOLO training run beside weights/.",
        "evaluation": evaluation, "evaluation_status": "available" if evaluation else "unavailable",
        "evaluation_message": None if evaluation else UNAVAILABLE}
