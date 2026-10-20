"""Evaluate a trained YOLO11n checkpoint on the prepared test split."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from model import create_yolo11n, read_dataset_yaml


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, required=True, help="Dataset YAML containing a group-aware test split")
    parser.add_argument("--weights", type=Path, required=True, help="Path to the trained best.pt checkpoint")
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--batch", type=int, default=8)
    parser.add_argument("--device", default="", help="For example: 0, cpu; empty lets Ultralytics choose")
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parent / "runs")
    parser.add_argument("--name", default="IT23183186_ModelB_YOLO11n_test")
    args = parser.parse_args()

    data_yaml = args.data.expanduser().resolve()
    read_dataset_yaml(data_yaml, require_test=True)
    weights = args.weights.expanduser().resolve()
    if not weights.is_file():
        raise FileNotFoundError(f"Trained checkpoint not found: {weights}")

    model = create_yolo11n(weights)
    metrics = model.val(
        data=str(data_yaml),
        split="test",
        imgsz=args.imgsz,
        batch=args.batch,
        device=args.device or None,
        plots=True,
        project=str(args.project.expanduser().resolve()),
        name=args.name,
    )
    if isinstance(model.names, dict):
        class_names = {
            str(index): str(model.names.get(index, model.names.get(str(index))))
            for index in range(len(model.names))
        }
    else:
        class_names = [str(name) for name in model.names]
    report: dict[str, Any] = {
        "dataset_yaml": str(data_yaml),
        "split": "test",
        "checkpoint": str(weights),
        "class_names": class_names,
        "metrics": {key: float(value) for key, value in metrics.results_dict.items()},
        "interpretation_limit": "FAIRHiveFrames classes describe hive-frame structures; this model is not a bee-disease classifier.",
    }
    output_dir = args.project.expanduser().resolve() / args.name
    output_dir.mkdir(parents=True, exist_ok=True)
    report_path = output_dir / "test_evaluation.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
