"""Shared dataset and reproducibility helpers for the Varroa classifier."""

from __future__ import annotations

import csv
import hashlib
import json
import math
import random
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image


EXPECTED_ROWS = {"train": 8225, "val": 1876, "test": 3408}
EXPECTED_LABELS = {
    "train": {"healthy": 5671, "varroa_positive": 2554},
    "val": {"healthy": 1425, "varroa_positive": 451},
    "test": {"healthy": 2466, "varroa_positive": 942},
}
CLASS_NAMES = ["healthy", "varroa_positive"]
RAW_LABEL_TO_CLASS = {0: 0, 1: 1, 3: 1}
SPLITS = ("train", "val", "test")


def parse_ground_truth(path: Path) -> list[dict[str, Any]]:
    """Parse the official whitespace-delimited gt.csv without altering it."""
    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8-sig") as stream:
        for line_number, line in enumerate(stream, start=1):
            fields = line.split()
            if not fields:
                continue
            if len(fields) < 2:
                raise ValueError(f"{path}:{line_number}: expected image path and label")
            relpath = fields[0].replace("\\", "/")
            parts = Path(relpath).parts
            split = parts[0].lower() if parts else ""
            if split not in SPLITS:
                raise ValueError(f"{path}:{line_number}: unknown split in {relpath!r}")
            raw_label = int(fields[1])
            if raw_label not in RAW_LABEL_TO_CLASS:
                raise ValueError(
                    f"{path}:{line_number}: unsupported raw label {raw_label}; refusing to infer a class"
                )
            coords = [float(value) for value in fields[2:]]
            if len(coords) % 4:
                raise ValueError(f"{path}:{line_number}: bounding-box fields are not groups of four")
            boxes = [coords[i : i + 4] for i in range(0, len(coords), 4)]
            rows.append(
                {
                    "relpath": relpath,
                    "split": split,
                    "raw_label": raw_label,
                    "label": RAW_LABEL_TO_CLASS[raw_label],
                    "boxes": boxes,
                    "line_number": line_number,
                }
            )
    return rows


def source_video_group(relpath: str) -> str | None:
    """Return the source-video identity encoded in the official image path."""
    parts = Path(relpath).parts
    if len(parts) < 4 or parts[1].lower() != "videos":
        return None
    video_name = parts[3].split("-bee_id", maxsplit=1)[0]
    return "/".join((parts[1], parts[2], video_name))


def unique_annotation_rows(rows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    by_path: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        by_path[row["relpath"]].append(row)
    unique: list[dict[str, Any]] = []
    duplicates: list[dict[str, Any]] = []
    for relpath, entries in sorted(by_path.items()):
        classes = {entry["label"] for entry in entries}
        if len(classes) != 1:
            raise ValueError(f"Conflicting class labels for the same image path: {relpath}")
        unique.append(entries[0])
        if len(entries) > 1:
            duplicates.append(
                {
                    "relpath": relpath,
                    "rows": len(entries),
                    "raw_labels": [entry["raw_label"] for entry in entries],
                    "bbox_annotation_sets": [entry["boxes"] for entry in entries],
                    "action": "one classification sample retained; original gt.csv unchanged",
                }
            )
    return unique, duplicates


def dataset_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    raw_counts = Counter(row["raw_label"] for row in rows)
    unique, duplicate_paths = unique_annotation_rows(rows)
    by_split_raw: dict[str, Counter[str]] = defaultdict(Counter)
    by_split_unique: dict[str, Counter[str]] = defaultdict(Counter)
    groups: dict[str, set[str]] = defaultdict(set)
    for row in rows:
        by_split_raw[row["split"]][CLASS_NAMES[row["label"]]] += 1
        group = source_video_group(row["relpath"])
        if group:
            groups[group].add(row["split"])
    for row in unique:
        by_split_unique[row["split"]][CLASS_NAMES[row["label"]]] += 1
    leakage_groups = {group: sorted(splits) for group, splits in groups.items() if len(splits) > 1}
    return {
        "annotation_rows": len(rows),
        "unique_image_paths": len(unique),
        "duplicate_annotation_paths": duplicate_paths,
        "raw_label_counts": {str(key): raw_counts[key] for key in sorted(raw_counts)},
        "mapping": {str(key): CLASS_NAMES[value] for key, value in RAW_LABEL_TO_CLASS.items()},
        "split_rows": {
            split: {
                "annotation_rows": sum(by_split_raw[split].values()),
                "class_counts": dict(by_split_raw[split]),
                "unique_image_paths": sum(by_split_unique[split].values()),
                "unique_class_counts": dict(by_split_unique[split]),
                "expected_official_rows": EXPECTED_ROWS[split],
                "expected_official_class_counts": EXPECTED_LABELS[split],
            }
            for split in SPLITS
        },
        "source_video_group_count": len(groups),
        "source_video_groups_crossing_splits": leakage_groups,
    }


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def md5_file(path: Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def perceptual_hash(image_path: Path) -> int:
    """Compute a deterministic 64-bit DCT perceptual hash without extra deps."""
    with Image.open(image_path) as image:
        pixels = np.asarray(image.convert("L").resize((32, 32), Image.Resampling.LANCZOS), dtype=np.float32)
    n = np.arange(32, dtype=np.float32)
    k = np.arange(8, dtype=np.float32)[:, None]
    basis = np.cos((np.pi / 32.0) * (n[None, :] + 0.5) * k)
    basis[0] *= 1.0 / math.sqrt(2.0)
    basis *= math.sqrt(2.0 / 32.0)
    low = basis @ pixels @ basis.T
    values = low.flatten()[1:]
    median = float(np.median(values))
    bits = low.flatten() >= median
    result = 0
    for bit in bits:
        result = (result << 1) | int(bit)
    return result


def global_ssim(left_path: Path, right_path: Path) -> float:
    """Quick aligned-image similarity used to review perceptual-hash candidates."""
    images = []
    for path in (left_path, right_path):
        with Image.open(path) as image:
            pixels = np.asarray(
                image.convert("L").resize((64, 112), Image.Resampling.BILINEAR),
                dtype=np.float64,
            ) / 255.0
        images.append(pixels)
    left, right = images
    mean_left, mean_right = float(left.mean()), float(right.mean())
    var_left, var_right = float(left.var()), float(right.var())
    covariance = float(((left - mean_left) * (right - mean_right)).mean())
    c1, c2 = 0.01**2, 0.03**2
    numerator = (2 * mean_left * mean_right + c1) * (2 * covariance + c2)
    denominator = (mean_left**2 + mean_right**2 + c1) * (var_left + var_right + c2)
    return numerator / denominator


def hamming_matches(left: list[int], right: list[int], threshold: int = 4) -> list[tuple[int, int, int]]:
    """Find near-duplicate pairs using bounded-memory vectorized XOR popcount."""
    if not left or not right:
        return []
    left_values = np.asarray(left, dtype=np.uint64)
    right_values = np.asarray(right, dtype=np.uint64)
    matches: list[tuple[int, int, int]] = []
    block = 64
    for start in range(0, len(left_values), block):
        xor = np.bitwise_xor(left_values[start : start + block, None], right_values[None, :])
        distances = np.bitwise_count(xor)
        rows, cols = np.where(distances <= threshold)
        matches.extend((start + int(i), int(j), int(distances[i, j])) for i, j in zip(rows, cols))
    return matches


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")


def seed_everything(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    try:
        import torch

        torch.manual_seed(seed)
        if torch.cuda.is_available():
            torch.cuda.manual_seed_all(seed)
        torch.use_deterministic_algorithms(True, warn_only=True)
        if hasattr(torch.backends, "cudnn"):
            torch.backends.cudnn.deterministic = True
            torch.backends.cudnn.benchmark = False
    except ImportError:
        pass


def write_manifest(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = ["relpath", "image_path", "split", "original_official_split", "label", "class_name", "raw_label", "source_video_group", "sha256", "phash"]
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows({field: row.get(field, "") for field in fields} for row in rows)
