"""Extract and audit official VarroaDataset splits; create reproducible manifests."""

from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from collections import defaultdict
from itertools import product
from pathlib import Path, PurePosixPath
from typing import Any

from PIL import Image, UnidentifiedImageError

from common import (
    CLASS_NAMES,
    EXPECTED_ROWS,
    hamming_matches,
    global_ssim,
    md5_file,
    parse_ground_truth,
    perceptual_hash,
    sha256_file,
    source_video_group,
    unique_annotation_rows,
    write_json,
    write_manifest,
)
from inspect_dataset import EXPECTED_MD5, inspect


def safe_extract(archive_path: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    base = destination.resolve()
    with zipfile.ZipFile(archive_path) as archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            member = PurePosixPath(info.filename)
            if member.is_absolute() or ".." in member.parts:
                raise ValueError(f"Unsafe member path in {archive_path.name}: {info.filename}")
            target = (destination / Path(*member.parts)).resolve()
            if not target.is_relative_to(base):
                raise ValueError(f"Archive member escapes destination: {info.filename}")
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(info) as source, target.open("wb") as output:
                for block in iter(lambda: source.read(1024 * 1024), b""):
                    output.write(block)


def locate_image(split_root: Path, relpath: str) -> Path | None:
    parts = PurePosixPath(relpath).parts
    suffix = parts[1:] if parts and parts[0].lower() in {"train", "val", "test"} else parts
    candidates = [split_root.joinpath(*parts), split_root.joinpath(*suffix)]
    for direct in candidates:
        if direct.is_file():
            return direct
    # Releases have appeared with and without the split prefix inside each zip.
    target_suffix = tuple(suffix[-3:])
    for candidate in split_root.rglob(PurePosixPath(relpath).name):
        candidate_parts = candidate.relative_to(split_root).parts
        if len(candidate_parts) >= len(target_suffix) and tuple(candidate_parts[-len(target_suffix) :]) == target_suffix:
            return candidate
    return None


def validate_box(row: dict[str, Any], width: int, height: int) -> list[str]:
    errors: list[str] = []
    for index, (x1, y1, x2, y2) in enumerate(row["boxes"]):
        if not (0 <= x1 < x2 <= width and 0 <= y1 < y2 <= height):
            errors.append(
                f"box {index}: ({x1:g},{y1:g},{x2:g},{y2:g}) outside valid {width}x{height} bounds"
            )
    return errors


def compare_hashes(records: list[dict[str, Any]], threshold: int = 4) -> dict[str, Any]:
    by_split: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in records:
        by_split[record["split"]].append(record)
    same_split: dict[str, dict[str, Any]] = {}
    cross_split: list[dict[str, Any]] = []
    cross_split_candidate_count = 0
    cross_split_confirmed_count = 0
    splits = ["train", "val", "test"]
    for split in splits:
        rows = by_split[split]
        values = [row["phash_int"] for row in rows]
        matches = hamming_matches(values, values, threshold)
        pairs = []
        for i, j, distance in matches:
            if i >= j:
                continue
            similarity = global_ssim(Path(rows[i]["image_path_absolute"]), Path(rows[j]["image_path_absolute"]))
            pairs.append(
                {
                    "left": rows[i]["relpath"],
                    "right": rows[j]["relpath"],
                    "distance": distance,
                    "global_ssim": similarity,
                    "confirmed_near_duplicate": similarity >= 0.90,
                }
            )
        same_split[split] = {
            "perceptual_hash_candidate_count": len(pairs),
            "confirmed_near_duplicate_count": sum(pair["confirmed_near_duplicate"] for pair in pairs),
            "candidate_pairs": pairs,
        }
    for i, left_split in enumerate(splits):
        for right_split in splits[i + 1 :]:
            left_rows, right_rows = by_split[left_split], by_split[right_split]
            matches = hamming_matches(
                [row["phash_int"] for row in left_rows],
                [row["phash_int"] for row in right_rows],
                threshold,
            )
            for li, ri, distance in matches:
                similarity = global_ssim(
                    Path(left_rows[li]["image_path_absolute"]),
                    Path(right_rows[ri]["image_path_absolute"]),
                )
                cross_split_candidate_count += 1
                cross_split_confirmed_count += int(similarity >= 0.90)
                if len(cross_split) < 1000:
                    cross_split.append(
                        {
                            "left_split": left_split,
                            "left": left_rows[li]["relpath"],
                            "right_split": right_split,
                            "right": right_rows[ri]["relpath"],
                            "distance": distance,
                            "global_ssim": similarity,
                            "confirmed_near_duplicate": similarity >= 0.90,
                        }
                    )
    return {
        "method": f"64-bit DCT perceptual hash; Hamming distance <= {threshold} is flagged for review",
        "within_split": same_split,
        "cross_split_perceptual_hash_candidate_count": cross_split_candidate_count,
        "cross_split_confirmed_near_duplicate_count": cross_split_confirmed_count,
        "cross_split_examples_limit": 1000,
        "cross_split_examples": cross_split,
    }


def create_grouped_splits(records: list[dict[str, Any]], near_duplicates: dict[str, Any]) -> dict[str, Any]:
    """Keep whole source videos and cross-split near-duplicate groups together."""
    parents: dict[str, str] = {}

    def find(item: str) -> str:
        parents.setdefault(item, item)
        if parents[item] != item:
            parents[item] = find(parents[item])
        return parents[item]

    def union(left: str, right: str) -> None:
        a, b = find(left), find(right)
        if a != b:
            parents[max(a, b)] = min(a, b)

    path_to_record = {row["relpath"]: row for row in records}
    for row in records:
        group = row["source_video_group"]
        if not group:
            raise ValueError(f"Cannot group image by source video: {row['relpath']}")
        find(group)
    all_pairs = list(near_duplicates["cross_split_examples"])
    for split_audit in near_duplicates["within_split"].values():
        all_pairs.extend(split_audit["candidate_pairs"])
    if near_duplicates["cross_split_perceptual_hash_candidate_count"] > len(near_duplicates["cross_split_examples"]):
        raise ValueError("Too many near-duplicate pairs to group safely; increase the audit limit before splitting.")
    for pair in all_pairs:
        if not pair["confirmed_near_duplicate"]:
            continue
        left_group = path_to_record[pair["left"]]["source_video_group"]
        right_group = path_to_record[pair["right"]]["source_video_group"]
        union(left_group, right_group)

    component_rows: dict[str, list[dict[str, Any]]] = defaultdict(list)
    component_groups: dict[str, set[str]] = defaultdict(set)
    for row in records:
        root = find(row["source_video_group"])
        component_rows[root].append(row)
        component_groups[root].add(row["source_video_group"])
    components = sorted(component_rows.items(), key=lambda item: item[0])
    if len(components) > 15:
        raise ValueError("Grouped split search is limited to 15 connected components; use a documented group splitter.")
    component_stats = []
    for component, rows in components:
        component_stats.append(
            (
                len(rows),
                {class_id: sum(row["label"] == class_id for row in rows) for class_id in (0, 1)},
            )
        )

    split_names = ("train", "val", "test")
    target_fraction = {"train": 0.50, "val": 0.25, "test": 0.25}
    total = len(records)
    total_classes = {class_id: sum(row["label"] == class_id for row in records) for class_id in (0, 1)}
    best: tuple[float, tuple[str, ...]] | None = None
    for assignment in product(split_names, repeat=len(components)):
        counts = {split: {class_id: 0 for class_id in (0, 1)} for split in split_names}
        sizes = {split: 0 for split in split_names}
        for (size, class_counts), split in zip(component_stats, assignment):
            sizes[split] += size
            for class_id in (0, 1):
                counts[split][class_id] += class_counts[class_id]
        if any(sizes[split] == 0 or any(counts[split][class_id] == 0 for class_id in (0, 1)) for split in split_names):
            continue
        size_loss = sum(((sizes[split] / total - target_fraction[split]) ** 2) / target_fraction[split] for split in split_names)
        class_loss = 0.0
        for split in split_names:
            for class_id in (0, 1):
                expected = total_classes[class_id] * target_fraction[split]
                class_loss += ((counts[split][class_id] - expected) / max(expected, 1.0)) ** 2
        score = size_loss + 0.20 * class_loss
        candidate = (score, assignment)
        if best is None or candidate < best:
            best = candidate
    if best is None:
        raise ValueError("Could not assign all grouped data to train/validation/test with both classes present.")

    assignment = best[1]
    details: dict[str, Any] = {}
    for (component, rows), split in zip(components, assignment):
        groups = sorted(component_groups[component])
        details[" | ".join(groups)] = {
            "prepared_split": split,
            "image_count": len(rows),
            "class_counts": {CLASS_NAMES[class_id]: sum(row["label"] == class_id for row in rows) for class_id in (0, 1)},
        }
        for row in rows:
            row["split"] = split
    return {
        "method": "Connected components of source-video groups joined by cross-official-split perceptual-hash candidates; exhaustive deterministic assignment minimizes size and class-distribution error against 50/25/25 targets.",
        "seed": 2026,
        "target_fractions": target_fraction,
        "actual_component_count": len(components),
        "component_assignments": details,
        "actual_split_counts": {
            split: {
                "image_count": sum(row["split"] == split for row in records),
                "class_counts": {CLASS_NAMES[class_id]: sum(row["split"] == split and row["label"] == class_id for row in records) for class_id in (0, 1)},
            }
            for split in split_names
        },
        "score": best[0],
    }


def prepare(source: Path, output: Path, force_extract: bool = False, report_copy: Path | None = None) -> dict[str, Any]:
    output.mkdir(parents=True, exist_ok=True)
    source = source.resolve()
    output = output.resolve()

    inspection = inspect(source, verify=True)
    if inspection["official_split_count_mismatches"]:
        raise ValueError("Official split counts do not match; see inspection report before preparing.")
    if inspection["cross_split_group_leakage"]:
        raise ValueError("Source video groups cross official splits; do not train until this is resolved.")
    for name, item in inspection["source_files"].items():
        if not item["exists"]:
            raise FileNotFoundError(f"Missing official dataset file: {source / name}")
        if not item.get("checksum_ok", False):
            raise ValueError(f"Checksum mismatch for {source / name}; preserve it and reacquire a valid copy.")

    rows = parse_ground_truth(source / "gt.csv")
    unique_rows, duplicate_annotation_paths = unique_annotation_rows(rows)
    raw_root = output / "raw"
    raw_root.mkdir(parents=True, exist_ok=True)
    extraction_report: dict[str, Any] = {}
    for split in ("train", "val", "test"):
        split_root = raw_root / split
        marker = split_root / ".extracted_from_official_zip.json"
        if force_extract or not marker.is_file():
            if split_root.exists():
                import shutil

                shutil.rmtree(split_root)
            split_root.mkdir(parents=True, exist_ok=True)
            archive_path = source / f"{split}.zip"
            safe_extract(archive_path, split_root)
            write_json(marker, {"archive": archive_path.name, "md5": EXPECTED_MD5[archive_path.name]})
        extraction_report[split] = {"archive": str(source / f"{split}.zip"), "destination": str(split_root)}

    manifest_candidates: dict[str, list[dict[str, Any]]] = defaultdict(list)
    missing_images: list[dict[str, str]] = []
    unreadable_images: list[dict[str, str]] = []
    wrong_dimensions: list[dict[str, Any]] = []
    invalid_boxes: list[dict[str, Any]] = []
    for row in unique_rows:
        image_path = locate_image(raw_root / row["split"], row["relpath"])
        if image_path is None:
            missing_images.append({"relpath": row["relpath"], "split": row["split"]})
            continue
        try:
            with Image.open(image_path) as image:
                image.verify()
            with Image.open(image_path) as image:
                width, height = image.size
                if (width, height) != (160, 280):
                    wrong_dimensions.append({"relpath": row["relpath"], "width": width, "height": height})
                box_errors = validate_box(row, width, height)
                if box_errors:
                    invalid_boxes.append({"relpath": row["relpath"], "errors": box_errors})
        except (OSError, UnidentifiedImageError, ValueError) as exc:
            unreadable_images.append({"relpath": row["relpath"], "error": str(exc)})
            continue
        digest = sha256_file(image_path)
        phash = perceptual_hash(image_path)
        manifest_candidates[row["split"]].append(
            {
                "relpath": row["relpath"],
                "image_path": image_path.relative_to(raw_root).as_posix(),
                "image_path_absolute": str(image_path),
                "split": row["split"],
                "original_official_split": row["split"],
                "label": row["label"],
                "class_name": CLASS_NAMES[row["label"]],
                "raw_label": row["raw_label"],
                "source_video_group": source_video_group(row["relpath"]) or "",
                "sha256": digest,
                "phash": f"{phash:016x}",
                "phash_int": phash,
            }
        )

    hash_owners: dict[str, dict[str, Any]] = {}
    exact_duplicate_images: list[dict[str, Any]] = []
    cross_split_exact_duplicates: list[dict[str, Any]] = []
    deduplicated: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for split in ("train", "val", "test"):
        for row in sorted(manifest_candidates[split], key=lambda item: item["relpath"]):
            previous = hash_owners.get(row["sha256"])
            if previous is None:
                hash_owners[row["sha256"]] = row
                deduplicated[split].append(row)
            elif previous["split"] == split:
                exact_duplicate_images.append(
                    {"kept": previous["relpath"], "excluded": row["relpath"], "split": split, "reason": "identical SHA-256 image bytes"}
                )
            else:
                cross_split_exact_duplicates.append(
                    {"left": previous["relpath"], "left_split": previous["split"], "right": row["relpath"], "right_split": split}
                )

    all_unique_records = [row for split in ("train", "val", "test") for row in deduplicated[split]]
    near_duplicate_report = compare_hashes(all_unique_records)
    if near_duplicate_report["cross_split_confirmed_near_duplicate_count"]:
        grouped_split_report = create_grouped_splits(all_unique_records, near_duplicate_report)
        for split in ("train", "val", "test"):
            deduplicated[split] = [row for row in all_unique_records if row["split"] == split]
    else:
        grouped_split_report = {
            "method": "Official train/val/test splits retained; no confirmed near-duplicate candidates cross split.",
            "official_split_preserved": True,
            "source_video_group_count": len({row["source_video_group"] for row in all_unique_records}),
        }
    post_reassignment_audit = compare_hashes(all_unique_records)
    session_splits: dict[str, set[str]] = defaultdict(set)
    for row in all_unique_records:
        if row["source_video_group"]:
            session_splits[row["source_video_group"]].add(row["split"])
    cross_split_sessions = {group: sorted(splits) for group, splits in session_splits.items() if len(splits) > 1}

    report = {
        "dataset": "VarroaDataset",
        "source": str(source),
        "output": str(output),
        "official_archives": extraction_report,
        "official_annotation_rows": len(rows),
        "unique_annotation_paths": len(unique_rows),
        "duplicate_annotation_paths": duplicate_annotation_paths,
        "class_mapping": {"0": "healthy", "1": "varroa_positive", "3": "varroa_positive"},
        "split_manifests": {},
        "image_validation": {
            "expected_dimensions": [160, 280],
            "missing_image_count": len(missing_images),
            "missing_images": missing_images,
            "unreadable_image_count": len(unreadable_images),
            "unreadable_images": unreadable_images,
            "wrong_dimension_count": len(wrong_dimensions),
            "wrong_dimensions": wrong_dimensions,
            "invalid_bbox_count": len(invalid_boxes),
            "invalid_bboxes": invalid_boxes,
        },
        "exact_duplicate_images_within_split": exact_duplicate_images,
        "exact_duplicate_images_across_splits": cross_split_exact_duplicates,
        "near_duplicate_audit": near_duplicate_report,
        "source_video_groups_crossing_splits": cross_split_sessions,
        "preprocessing": {
            "input_size": [224, 224],
            "resize_and_normalization": "aspect-preserving bilinear fit to 224x224, padding filled with the pretrained weight mean, then exact ImageNet mean/std normalization from MobileNet_V2_Weights.IMAGENET1K_V1",
            "augmentation": "training split only; horizontal flip, small rotation, mild color jitter",
            "validation_test_augmentation": False,
            "split_policy": "official train/val/test retained because no confirmed near-duplicate candidates or source-video groups cross splits",
            "seed": 2026,
        },
        "grouped_split_strategy": grouped_split_report,
        "near_duplicate_audit_before_reassignment": near_duplicate_report,
        "near_duplicate_audit_after_split_policy": post_reassignment_audit,
        "bbox_note": "Bounding boxes are not used in this image-classification task. Invalid boxes are retained in the original annotation file and reported; image-level class labels remain unchanged.",
        "exclusion_policy": "No images are discarded because of near-duplicate candidates: cross-split candidates are reassigned to training and recorded. Duplicate annotation rows for one path and exact duplicate image bytes within a split are reduced to one classifier-manifest row with each case recorded. Corrupt, missing, cross-split exact duplicates, or video-group leakage stop preparation. Invalid boxes are reported but do not affect this classifier's image-level labels.",
    }
    if missing_images or unreadable_images or cross_split_exact_duplicates or cross_split_sessions or post_reassignment_audit["cross_split_confirmed_near_duplicate_count"]:
        report_path = output / "preparation_report.json"
        write_json(report_path, report)
        if report_copy:
            write_json(report_copy, report)
        raise ValueError(f"Dataset validation found blocking issues; see {report_path}")

    for split in ("train", "val", "test"):
        manifest_path = output / "manifests" / f"{split}.csv"
        write_manifest(manifest_path, deduplicated[split])
        counts = {name: sum(row["class_name"] == name for row in deduplicated[split]) for name in CLASS_NAMES}
        report["split_manifests"][split] = {
            "path": str(manifest_path),
            "image_count": len(deduplicated[split]),
            "class_counts": counts,
        }
    report["output_class_names"] = CLASS_NAMES
    report_path = output / "preparation_report.json"
    write_json(report_path, report)
    if report_copy:
        write_json(report_copy, report)
    print(json.dumps({
        "report": str(report_path),
        "image_validation": report["image_validation"],
        "split_manifests": report["split_manifests"],
        "duplicate_annotation_paths": len(duplicate_annotation_paths),
        "exact_duplicate_images_within_split": len(exact_duplicate_images),
        "cross_split_exact_duplicates": len(cross_split_exact_duplicates),
        "cross_split_perceptual_hash_candidates": near_duplicate_report["cross_split_perceptual_hash_candidate_count"],
        "confirmed_cross_split_near_duplicates": near_duplicate_report["cross_split_confirmed_near_duplicate_count"],
    }, indent=2))
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True, help="Directory with official VarroaDataset downloads")
    parser.add_argument("--output", type=Path, required=True, help="Separate prepared-data output directory")
    parser.add_argument("--force-extract", action="store_true", help="Re-extract source zips to the prepared-data directory")
    parser.add_argument("--report-copy", type=Path, help="Optional second copy of the JSON preparation report")
    args = parser.parse_args()
    prepare(args.source, args.output, force_extract=args.force_extract, report_copy=args.report_copy)


if __name__ == "__main__":
    main()
