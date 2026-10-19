"""Audit image/YOLO-label pairs in configured FAIRHiveFrames splits."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, UnidentifiedImageError

from model import FAIRHIVE_CLASS_NAMES, read_dataset_yaml

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}


def dhash(image: Image.Image) -> int:
    image = image.convert("L").resize((9, 8), Image.Resampling.LANCZOS)
    values = list(image.getdata())
    result = 0
    for row in range(8):
        for col in range(8):
            result = (result << 1) | int(values[row * 9 + col] > values[row * 9 + col + 1])
    return result


def label_for(image_path: Path) -> Path:
    parts = list(image_path.parts)
    for index, part in enumerate(parts):
        if part.lower() == "images":
            parts[index] = "labels"
            return Path(*parts).with_suffix(".txt")
    return image_path.with_suffix(".txt")


def audit(data_yaml: Path) -> dict:
    config, root = read_dataset_yaml(data_yaml, require_test=True)
    report = {
        "dataset_yaml": str(data_yaml.resolve()),
        "classes": FAIRHIVE_CLASS_NAMES,
        "splits": {},
        "errors": [],
        "duplicate_image_bytes": [],
        "near_duplicate_candidates_dhash_le_4": [],
        "group_overlap": [],
    }
    global_hashes: dict[str, tuple[str, str]] = {}
    all_images: list[tuple[str, Path, int]] = []
    groups: dict[str, set[str]] = {}
    for split in ("train", "val", "test"):
        raw = config[split]
        roots = [raw] if isinstance(raw, str) else raw
        images = []
        for entry in roots:
            candidate = Path(str(entry))
            if not candidate.is_absolute():
                candidate = root / candidate
            if candidate.is_dir():
                images.extend(path for path in candidate.rglob("*") if path.suffix.lower() in IMAGE_SUFFIXES)
            elif candidate.is_file() and candidate.suffix.lower() in IMAGE_SUFFIXES:
                images.append(candidate)
        counts = {name: 0 for name in FAIRHIVE_CLASS_NAMES}
        class_image_counts = {name: 0 for name in FAIRHIVE_CLASS_NAMES}
        annotation_count = 0
        split_group_keys: set[str] = set()
        for image_path in sorted(set(images)):
            try:
                with Image.open(image_path) as image:
                    image.verify()
                with Image.open(image_path) as image:
                    dh = dhash(image)
            except (UnidentifiedImageError, OSError) as exc:
                report["errors"].append({"split": split, "image": image_path.name, "error": "unreadable image"})
                continue
            digest = hashlib.sha256(image_path.read_bytes()).hexdigest()
            if digest in global_hashes:
                old_split, old_name = global_hashes[digest]
                report["duplicate_image_bytes"].append({"first_split": old_split, "first_image": old_name, "split": split, "image": image_path.name})
            else:
                global_hashes[digest] = (split, image_path.name)
            label_path = label_for(image_path)
            if not label_path.is_file():
                report["errors"].append({"split": split, "image": image_path.name, "error": "matching label file missing"})
                continue
            try:
                lines = label_path.read_text(encoding="utf-8").splitlines()
            except OSError:
                report["errors"].append({"split": split, "image": image_path.name, "error": "label file unreadable"})
                continue
            image_classes: set[str] = set()
            for line_number, line in enumerate(lines, 1):
                fields = line.split()
                if len(fields) != 5:
                    report["errors"].append({"split": split, "image": image_path.name, "line": line_number, "error": "YOLO label must contain class id and four box values"})
                    continue
                try:
                    class_id = int(fields[0])
                    x, y, width, height = map(float, fields[1:])
                except ValueError:
                    report["errors"].append({"split": split, "image": image_path.name, "line": line_number, "error": "non-numeric YOLO label"})
                    continue
                if not 0 <= class_id < len(FAIRHIVE_CLASS_NAMES):
                    report["errors"].append({"split": split, "image": image_path.name, "line": line_number, "error": "class id out of range"})
                    continue
                if not all(0 <= value <= 1 for value in (x, y, width, height)) or width <= 0 or height <= 0 or x - width / 2 < 0 or y - height / 2 < 0 or x + width / 2 > 1 or y + height / 2 > 1:
                    report["errors"].append({"split": split, "image": image_path.name, "line": line_number, "error": "box is non-positive or outside normalized image bounds"})
                    continue
                counts[FAIRHIVE_CLASS_NAMES[class_id]] += 1
                image_classes.add(FAIRHIVE_CLASS_NAMES[class_id])
                annotation_count += 1
            for class_name in image_classes:
                class_image_counts[class_name] += 1
            try:
                relative = image_path.resolve().relative_to(root.resolve())
                group = str(relative.parent).replace("\\", "/")
                group = group.removeprefix("images/")
                if group.split("/", 1)[0] in {"train", "val", "valid", "validation", "test"}:
                    group = group.split("/", 1)[1] if "/" in group else ""
                split_group_keys.add(group)
            except ValueError:
                pass
            all_images.append((split, image_path, dh))
        groups[split] = split_group_keys
        report["splits"][split] = {
            "image_count": len(images),
            "annotation_count": annotation_count,
            "images_per_class": class_image_counts,
            "annotations_per_class": counts,
        }
    splits = list(groups)
    for i, left in enumerate(splits):
        for right in splits[i + 1:]:
            for group in sorted(groups[left] & groups[right]):
                if group not in (".", ""):
                    report["group_overlap"].append({"group": group, "splits": [left, right]})
    for i, (split_a, image_a, hash_a) in enumerate(all_images):
        for split_b, image_b, hash_b in all_images[i + 1:]:
            if split_a != split_b and (hash_a ^ hash_b).bit_count() <= 4:
                report["near_duplicate_candidates_dhash_le_4"].append({"left_split": split_a, "left_image": image_a.name, "right_split": split_b, "right_image": image_b.name})
    report["near_duplicate_review_required"] = bool(report["near_duplicate_candidates_dhash_le_4"])
    report["passed"] = (
        not report["errors"]
        and not report["duplicate_image_bytes"]
        and not report["group_overlap"]
        and not report["near_duplicate_review_required"]
    )
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, required=True, help="Prepared dataset YAML with a group-aware test split")
    parser.add_argument("--output", type=Path, required=True, help="JSON report output path")
    args = parser.parse_args()
    try:
        result = audit(args.data.expanduser().resolve())
    except (FileNotFoundError, ValueError) as exc:
        result = {
            "dataset_yaml": args.data.name,
            "classes": FAIRHIVE_CLASS_NAMES,
            "splits": {},
            "errors": [{"error": str(exc)}],
            "duplicate_image_bytes": [],
            "near_duplicate_candidates_dhash_le_4": [],
            "group_overlap": [],
            "passed": False,
        }
    output = args.output.expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    if not result["passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
