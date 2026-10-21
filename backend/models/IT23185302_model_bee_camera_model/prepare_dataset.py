
from pathlib import Path
import shutil
import yaml

# Original dataset
SOURCE = Path(
    r"D:\Bee_Camera_Model\Labeled dataset for bee detection and direction estimation on beehive landing boards\detection"
)

# Model project folder
BASE = Path(__file__).resolve().parent
OUTPUT = BASE / "dataset"

# Split entire recording folders to prevent data leakage.
# We have 8 recording folders.
SPLITS = {
    "train": [
        "_bee_20230609a",
        "_bee_20230609b",
        "_bee_20230609c",
        "_bee_20230609d",
        "_bee_20230609e",
        "_bee_20230711a",
    ],
    "val": ["_bee_20230711b"],
    "test": ["_bee_20230711c"],
}

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}


def valid_label(label_path):
    """Check whether a label follows YOLO detection format."""
    try:
        for line in label_path.read_text(
            encoding="utf-8-sig"
        ).splitlines():
            if not line.strip():
                continue

            parts = line.split()
            if len(parts) != 5:
                return False

            class_id = int(parts[0])
            x, y, w, h = map(float, parts[1:])

            if class_id != 0:
                return False

            if not (
                0 <= x <= 1 and 0 <= y <= 1
                and 0 < w <= 1 and 0 < h <= 1
                and x - w / 2 >= -0.00001
                and y - h / 2 >= -0.00001
                and x + w / 2 <= 1.00001
                and y + h / 2 <= 1.00001
            ):
                return False

        return True
    except (ValueError, OSError):
        return False


def prepare():
    if not SOURCE.is_dir():
        raise FileNotFoundError(f"Dataset not found: {SOURCE}")

    if (OUTPUT / "images").exists() or (OUTPUT / "labels").exists():
        raise RuntimeError(
            "Output dataset already exists. "
            "Move or rename it before running again."
        )

    counts = {}

    for split, folders in SPLITS.items():
        image_out = OUTPUT / "images" / split
        label_out = OUTPUT / "labels" / split

        image_out.mkdir(parents=True, exist_ok=True)
        label_out.mkdir(parents=True, exist_ok=True)

        copied = 0
        missing = 0
        invalid = 0

        for folder_name in folders:
            images_dir = SOURCE / folder_name / "images"
            labels_dir = SOURCE / folder_name / "labels"

            if not images_dir.is_dir() or not labels_dir.is_dir():
                raise FileNotFoundError(
                    f"Missing images or labels folder: {folder_name}"
                )

            for image in sorted(images_dir.iterdir()):
                if image.suffix.lower() not in IMAGE_EXTENSIONS:
                    continue

                label = labels_dir / f"{image.stem}.txt"

                if not label.exists():
                    missing += 1
                    continue

                if not valid_label(label):
                    invalid += 1
                    continue

                # Prefix prevents duplicate names across recordings.
                new_stem = f"{folder_name}_{image.stem}"

                shutil.copy2(
                    image,
                    image_out / f"{new_stem}{image.suffix}"
                )
                shutil.copy2(
                    label,
                    label_out / f"{new_stem}.txt"
                )
                copied += 1

        counts[split] = copied
        print(f"\n{split.upper()}")
        print(f"Copied: {copied}")
        print(f"Missing labels skipped: {missing}")
        print(f"Invalid labels skipped: {invalid}")

    config = {
        "path": str(OUTPUT.resolve()).replace("\\", "/"),
        "train": "images/train",
        "val": "images/val",
        "test": "images/test",
        "nc": 1,
        "names": {0: "bee"},
    }

    with open(OUTPUT / "data.yaml", "w", encoding="utf-8") as file:
        yaml.safe_dump(config, file, sort_keys=False)

    print("\n===== PREPROCESSING COMPLETE =====")
    print("Total prepared images:", sum(counts.values()))
    print("Dataset location:", OUTPUT)
    print("Configuration:", OUTPUT / "data.yaml")


if __name__ == "__main__":
    prepare()
