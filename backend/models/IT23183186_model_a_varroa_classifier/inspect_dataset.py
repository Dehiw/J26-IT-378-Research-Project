"""Inspect the official VarroaDataset release and its split annotations."""

from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path
from typing import Any

from common import EXPECTED_LABELS, EXPECTED_ROWS, dataset_summary, parse_ground_truth, write_json


EXPECTED_MD5 = {
    "train.zip": "87cb443aa28650ef34e83b2d1b3fa26d",
    "val.zip": "631318f802b059e5274b0b26c4c0a593",
    "test.zip": "a510921655dae21c10b5389fa0cfeef5",
    "gt.csv": "46889d2689eac833c6eb89a95085b8ef",
}
EXPECTED_SIZE = {
    "train.zip": 703410525,
    "val.zip": 163050592,
    "test.zip": 291715596,
    "gt.csv": 1226427,
}


def inspect(source: Path, verify: bool = False) -> dict[str, Any]:
    gt_path = source / "gt.csv"
    if not gt_path.exists() and (source / "gt_inspect.csv").exists():
        gt_path = source / "gt_inspect.csv"
    if not gt_path.is_file():
        raise FileNotFoundError(f"Could not find gt.csv in {source}")

    rows = parse_ground_truth(gt_path)
    summary = dataset_summary(rows)
    files: dict[str, Any] = {}
    for name in EXPECTED_MD5:
        path = source / name
        item: dict[str, Any] = {"exists": path.is_file()}
        if path.is_file():
            item["size_bytes"] = path.stat().st_size
            item["expected_size_bytes"] = EXPECTED_SIZE[name]
            if name.endswith(".zip"):
                try:
                    with zipfile.ZipFile(path) as archive:
                        names = [entry for entry in archive.namelist() if not entry.endswith("/")]
                    item["archive_files"] = len(names)
                    item["image_files"] = sum(Path(entry).suffix.lower() in {".png", ".jpg", ".jpeg"} for entry in names)
                    item["sample_entries"] = names[:5]
                except zipfile.BadZipFile:
                    item["valid_zip"] = False
                else:
                    item["valid_zip"] = True
            if verify:
                from common import md5_file

                actual_md5 = md5_file(path)
                item["md5"] = actual_md5
                item["expected_md5"] = EXPECTED_MD5[name]
                item["checksum_ok"] = actual_md5 == EXPECTED_MD5[name]
        files[name] = item

    split_mismatches = {}
    for split, expected in EXPECTED_ROWS.items():
        actual = summary["split_rows"][split]
        if actual["annotation_rows"] != expected or actual["class_counts"] != EXPECTED_LABELS[split]:
            split_mismatches[split] = {
                "actual_rows": actual["annotation_rows"],
                "actual_classes": actual["class_counts"],
                "expected_rows": expected,
                "expected_classes": EXPECTED_LABELS[split],
            }

    return {
        "dataset": "VarroaDataset",
        "source": "https://zenodo.org/records/4085044",
        "ground_truth_file": str(gt_path),
        "annotation_format": "whitespace-delimited: relative_image_path label [zero or more x1 y1 x2 y2 boxes]",
        "image_dimensions_documented_width_height": [160, 280],
        "official_split_strategy": "Use released train/val/test splits; source video group identities are retained and audited.",
        "label_mapping": {
            "0": "healthy",
            "1": "varroa_positive",
            "3": "varroa_positive",
        },
        "label_mapping_note": (
            "The global gt.csv includes raw labels 0, 1, and 3. Labels 1 and 3 together match the official infected count; "
            "label 3 is therefore retained as Varroa-positive in the binary task. Unknown values fail validation."
        ),
        **summary,
        "cross_split_group_leakage": summary["source_video_groups_crossing_splits"],
        "official_split_count_mismatches": split_mismatches,
        "source_files": files,
        "data_license": "CC-BY-4.0 (Zenodo metadata)",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True, help="Directory containing train.zip, val.zip, test.zip, and gt.csv")
    parser.add_argument("--output", type=Path, help="Optional JSON report path")
    parser.add_argument("--verify-checksums", action="store_true", help="Verify files against Zenodo MD5 checksums")
    args = parser.parse_args()
    report = inspect(args.source.resolve(), verify=args.verify_checksums)
    report_path = args.output or (args.source / "inspection_report.json")
    write_json(report_path, report)
    print(json.dumps({
        "annotation_rows": report["annotation_rows"],
        "unique_image_paths": report["unique_image_paths"],
        "raw_label_counts": report["raw_label_counts"],
        "split_rows": report["split_rows"],
        "duplicate_annotation_paths": len(report["duplicate_annotation_paths"]),
        "cross_split_group_leakage": report["cross_split_group_leakage"],
        "split_count_mismatches": report["official_split_count_mismatches"],
        "report": str(report_path.resolve()),
    }, indent=2))
    if report["official_split_count_mismatches"]:
        raise SystemExit("Official counts do not match this gt.csv; inspect the report before training.")
    if report["cross_split_group_leakage"]:
        raise SystemExit("Source video sessions cross official splits; stop and resolve leakage before training.")


if __name__ == "__main__":
    main()
