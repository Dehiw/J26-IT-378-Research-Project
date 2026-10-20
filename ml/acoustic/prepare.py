"""Step 2: combine the metadata and draw a balanced, reproducible sample.

Output: data/manifest.csv (one row per sampled clip; no audio is copied).

Run:  python prepare.py
"""


import numpy as np
import pandas as pd

import config


def load_source(name: str, filename: str) -> pd.DataFrame:
    """Read one metadata file and return the columns needed for training."""
    df = pd.read_hdf(config.DATA_ROOT / filename, config.METADATA_KEY)

    if name == "TBON":
        df = df[df["bee presence"] == config.TBON_BEE_PRESENCE_VALUE]

    out = pd.DataFrame(
        {
            "dataset": name,
            "hive_number": df["hive number"].astype(int).to_numpy(),
            "label": df["queen presence"].astype(int).to_numpy(),
            "file_path": df["file path"].astype(str).to_numpy(),
        }
    )
    out["hive_id"] = out["dataset"] + "-" + out["hive_number"].astype(str)
    return out


def load_all() -> pd.DataFrame:
    frames = []
    for name, filename in config.SOURCES.items():
        part = load_source(name, filename)
        print(f"  {name:7s} {len(part):7d} labelled clips")
        frames.append(part)
    pool = pd.concat(frames, ignore_index=True)
    print(f"  total   {len(pool):7d} clips in the pool (BAD excluded)")
    return pool


def water_fill(total: int, available: dict) -> dict:
    """Split `total` as evenly as possible over the keys of `available`.

    A key with fewer items than its share gives all of them, and the rest is
    shared among the others. Returns how many to take from each key.
    """
    take = {key: 0 for key in available}
    remaining = total
    keys = sorted(available, key=lambda k: available[k])
    for i, key in enumerate(keys):
        share = remaining // (len(keys) - i)
        take[key] = min(available[key], share)
        remaining -= take[key]
    return take


def draw_sample(pool: pd.DataFrame) -> pd.DataFrame:
    per_label = config.TARGET_TOTAL // 2
    pieces = []
    for label in sorted(pool["label"].unique()):
        in_label = pool[pool["label"] == label]
        available = in_label.groupby("hive_id").size().to_dict()
        plan = water_fill(per_label, available)
        short = per_label - sum(plan.values())
        if short > 0:
            print(f"  WARNING: label {label} is short by {short} clips")
        for hive_id, n in plan.items():
            rows = in_label[in_label["hive_id"] == hive_id]
            pieces.append(rows.sample(n=n, random_state=config.SEED))
    sample = pd.concat(pieces, ignore_index=True)
    return sample.sample(frac=1.0, random_state=config.SEED).reset_index(drop=True)


def check_files_exist(sample: pd.DataFrame) -> None:
    missing = []
    for dataset, rel in zip(sample["dataset"], sample["file_path"]):
        full = config.DATA_ROOT / dataset / rel
        if not full.exists():
            missing.append(str(full))
    if missing:
        raise FileNotFoundError(
            f"{len(missing)} sampled files are missing, e.g. {missing[:3]}"
        )
    print(f"  all {len(sample)} sampled files exist on disk")


def print_counts(sample: pd.DataFrame) -> None:
    print("\nCounts per dataset / hive / label:")
    table = (
        sample.groupby(["dataset", "hive_id", "label"])
        .size()
        .unstack("label", fill_value=0)
        .rename(columns=config.LABEL_NAMES)
    )
    table["total"] = table.sum(axis=1)
    print(table.to_string())

    print("\nTotals per label:")
    for label, n in sample["label"].value_counts().sort_index().items():
        print(f"  {config.LABEL_NAMES[label]:14s} {n:6d}")
    print(f"  {'TOTAL':14s} {len(sample):6d}")


def main() -> None:
    config.DATA_DIR.mkdir(parents=True, exist_ok=True)
    print("Reading metadata from", config.DATA_ROOT)
    pool = load_all()

    print("\nDrawing the balanced sample (seed", config.SEED, ")")
    sample = draw_sample(pool)

    print("\nChecking files:")
    check_files_exist(sample)

    manifest = sample[["dataset", "hive_id", "hive_number", "label", "file_path"]]
    manifest.to_csv(config.MANIFEST_PATH, index=False)
    print(f"\nSaved {config.MANIFEST_PATH} ({len(manifest)} rows)")
    print_counts(manifest)


if __name__ == "__main__":
    main()
