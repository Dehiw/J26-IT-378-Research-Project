"""YOLO11n architecture and strict FAIRHiveFrames dataset-config checks."""

from __future__ import annotations

from pathlib import Path
from typing import Any


FAIRHIVE_CLASS_NAMES = [
    "CappedHoneyCell",
    "CappedWorkerBroodCell",
    "EmptyCombCell",
    "PollenCell",
    "UncappedNectarCell",
    "UncappedWorkerLarvaCell",
    "BeeHiveFrame",
]


def read_dataset_yaml(data_yaml: Path, *, require_test: bool = False) -> tuple[dict[str, Any], Path]:
    """Read a YOLO data YAML and reject missing splits or an altered class map."""
    try:
        import yaml
    except ImportError as exc:  # pragma: no cover - message for user setup
        raise RuntimeError("Install the Model B requirements before using this script.") from exc

    data_yaml = data_yaml.expanduser().resolve()
    if not data_yaml.is_file():
        raise FileNotFoundError(f"Dataset YAML not found: {data_yaml}")
    with data_yaml.open("r", encoding="utf-8") as stream:
        config = yaml.safe_load(stream)
    if not isinstance(config, dict):
        raise ValueError(f"Dataset YAML must contain a mapping: {data_yaml}")

    names = config.get("names")
    if isinstance(names, dict):
        try:
            names = [names.get(index, names.get(str(index))) for index in range(len(names))]
        except (TypeError, ValueError):
            names = None
    if names != FAIRHIVE_CLASS_NAMES:
        raise ValueError(
            "The dataset class map must exactly match the seven verified "
            f"FAIRHiveFrames classes in order: {FAIRHIVE_CLASS_NAMES!r}. "
            "Do not substitute disease labels."
        )

    root_value = config.get("path")
    root = Path(root_value).expanduser() if root_value else data_yaml.parent
    if not root.is_absolute():
        root = data_yaml.parent / root
    root = root.resolve()

    required = ["train", "val"] + (["test"] if require_test else [])
    for split in required:
        value = config.get(split)
        if not value:
            raise ValueError(f"Dataset YAML must define the {split!r} split before running this command.")
        values = value if isinstance(value, list) else [value]
        for entry in values:
            candidate = Path(str(entry)).expanduser()
            if not candidate.is_absolute():
                candidate = root / candidate
            if not candidate.exists():
                raise FileNotFoundError(f"Configured {split} path does not exist: {candidate}")

    return config, root


def create_yolo11n(weights: str | Path = "yolo11n.pt"):
    """Load the official Ultralytics YOLO11n detection architecture/weights."""
    try:
        from ultralytics import YOLO
    except ImportError as exc:  # pragma: no cover - message for user setup
        raise RuntimeError("Install the Model B requirements before using YOLO11n.") from exc
    return YOLO(str(weights))
