"""Train YOLO11n on a verified FAIRHiveFrames YOLO-format dataset."""

from __future__ import annotations

import argparse
from pathlib import Path

from model import create_yolo11n, read_dataset_yaml


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, required=True, help="Prepared dataset YAML with verified train/val splits")
    parser.add_argument("--weights", default="yolo11n.pt", help="Official pretrained YOLO11n checkpoint or YAML")
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--batch", type=int, default=8)
    parser.add_argument("--patience", type=int, default=20)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--seed", type=int, default=2026)
    parser.add_argument("--device", default="", help="For example: 0, cpu; empty lets Ultralytics choose")
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parent / "runs")
    parser.add_argument("--name", default="fairhive_yolo11n")
    args = parser.parse_args()

    data_yaml = args.data.expanduser().resolve()
    read_dataset_yaml(data_yaml)
    model = create_yolo11n(args.weights)
    model.train(
        data=str(data_yaml),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        patience=args.patience,
        seed=args.seed,
        deterministic=True,
        workers=args.workers,
        device=args.device or None,
        project=str(args.project.expanduser().resolve()),
        name=args.name,
        pretrained=True,
        plots=True,
        save=True,
    )


if __name__ == "__main__":
    # Required by Windows multiprocessing when Ultralytics uses DataLoader workers.
    main()
