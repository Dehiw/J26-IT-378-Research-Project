from pathlib import Path

DATASET_PATH = Path(
    r"D:\Bee_Camera_Model\Labeled dataset for bee detection and direction estimation on beehive landing boards\detection"
)

total_images = 0
total_labels = 0
missing_labels = 0

for folder in sorted(DATASET_PATH.iterdir()):
    if not folder.is_dir():
        continue

    images_dir = folder / "images"
    labels_dir = folder / "labels"

    if not images_dir.exists() or not labels_dir.exists():
        print(f"Skipping {folder.name}: images/labels missing")
        continue

    images = [
        p for p in images_dir.iterdir()
        if p.suffix.lower() in [".jpg", ".jpeg", ".png"]
    ]

    labels = list(labels_dir.glob("*.txt"))

    missing = sum(
        1 for image in images
        if not (labels_dir / f"{image.stem}.txt").exists()
    )

    total_images += len(images)
    total_labels += len(labels)
    missing_labels += missing

    print(f"\nFolder: {folder.name}")
    print(f"Images: {len(images)}")
    print(f"Labels: {len(labels)}")
    print(f"Missing labels: {missing}")

print("\n====== DATASET SUMMARY ======")
print(f"Total images: {total_images}")
print(f"Total labels: {total_labels}")
print(f"Images without labels: {missing_labels}")