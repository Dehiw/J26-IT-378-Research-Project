"""Evaluate the saved MobileNetV2 model once on the untouched official test split."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any

import numpy as np
import torch
import torchvision
from PIL import Image
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, roc_auc_score
from torch.utils.data import DataLoader, Dataset
from torchvision.models import MobileNet_V2_Weights

from common import CLASS_NAMES, write_json
from model import create_mobilenet_v2_classifier
from train import AspectPreservingLetterbox


class TestManifestDataset(Dataset):
    def __init__(self, manifest: Path, root: Path, transform: Any) -> None:
        with manifest.open("r", encoding="utf-8", newline="") as stream:
            self.rows = list(csv.DictReader(stream))
        if not self.rows:
            raise ValueError(f"Empty test manifest: {manifest}")
        self.root = root
        self.transform = transform

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, int, str]:
        row = self.rows[index]
        path = self.root / Path(row["image_path"])
        with Image.open(path) as source:
            image = source.convert("RGB")
        return self.transform(image), int(row["label"]), row["relpath"]


@torch.inference_mode()
def evaluate(model: torch.nn.Module, loader: DataLoader, device: torch.device) -> tuple[np.ndarray, np.ndarray, list[str]]:
    model.eval()
    labels: list[np.ndarray] = []
    probabilities: list[np.ndarray] = []
    paths: list[str] = []
    for images, batch_labels, batch_paths in loader:
        logits = model(images.to(device))
        labels.append(batch_labels.numpy())
        probabilities.append(torch.softmax(logits, dim=1)[:, 1].cpu().numpy())
        paths.extend(batch_paths)
    return np.concatenate(labels), np.concatenate(probabilities), paths


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepared-dir", type=Path, required=True)
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, help="Defaults to model-dir/evaluation")
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--workers", type=int, default=0)
    parser.add_argument("--cpu-threads", type=int, default=8)
    args = parser.parse_args()
    args.prepared_dir = args.prepared_dir.resolve()
    args.model_dir = args.model_dir.resolve()
    output_dir = (args.output_dir or args.model_dir / "evaluation").resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    torch.set_num_threads(max(1, args.cpu_threads))

    checkpoint_path = args.model_dir / "best_model.pt"
    checkpoint = torch.load(checkpoint_path, map_location=device, weights_only=False)
    model = create_mobilenet_v2_classifier(pretrained=False)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.to(device)

    transform = AspectPreservingLetterbox(MobileNet_V2_Weights.IMAGENET1K_V1)
    dataset = TestManifestDataset(args.prepared_dir / "manifests" / "test.csv", args.prepared_dir / "raw", transform)
    loader = DataLoader(dataset, batch_size=args.batch_size, shuffle=False, num_workers=args.workers, pin_memory=device.type == "cuda")
    y_true, y_prob, paths = evaluate(model, loader, device)
    threshold = float(checkpoint["best_validation"]["threshold"])
    y_pred = (y_prob >= threshold).astype(np.int64)
    report = classification_report(
        y_true,
        y_pred,
        labels=[0, 1],
        target_names=CLASS_NAMES,
        output_dict=True,
        zero_division=0,
    )
    matrix = confusion_matrix(y_true, y_pred, labels=[0, 1]).tolist()
    result = {
        "dataset": "official VarroaDataset test split",
        "test_manifest": str(args.prepared_dir / "manifests" / "test.csv"),
        "test_set_used_for_model_selection": False,
        "checkpoint": str(checkpoint_path),
        "device": str(device),
        "torch_version": torch.__version__,
        "torchvision_version": torchvision.__version__,
        "threshold_selected_on_validation": threshold,
        "test_count": int(len(y_true)),
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "roc_auc": float(roc_auc_score(y_true, y_prob)) if len(np.unique(y_true)) == 2 else None,
        "confusion_matrix_labels_order": CLASS_NAMES,
        "confusion_matrix": matrix,
        "per_class": report,
        "varroa_positive_recall": float(report["varroa_positive"]["recall"]),
        "interpretation_limit": "Evaluation is on controlled individual-bee crops from VarroaDataset; it does not establish performance on whole-hive photographs or Sri Lankan field images.",
    }
    write_json(output_dir / "test_evaluation.json", result)
    with (output_dir / "test_predictions.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["relpath", "true_class", "positive_probability", "threshold", "predicted_class"])
        for path, truth, probability, prediction in zip(paths, y_true, y_prob, y_pred):
            writer.writerow([path, CLASS_NAMES[int(truth)], float(probability), threshold, CLASS_NAMES[int(prediction)]])
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
