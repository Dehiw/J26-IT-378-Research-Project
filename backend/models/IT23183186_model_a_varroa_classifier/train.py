"""Train a reproducible MobileNetV2 classifier on prepared VarroaDataset manifests."""

from __future__ import annotations

import argparse
import csv
import json
import platform
import sys
import time
from pathlib import Path
from typing import Any

import numpy as np
import torch
import torch.nn as nn
import torchvision
from PIL import Image
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score, roc_auc_score
from torch.utils.data import DataLoader, Dataset
from torchvision.models import MobileNet_V2_Weights
from torchvision import transforms
from torchvision.transforms import InterpolationMode

from common import CLASS_NAMES, seed_everything, write_json
from model import create_mobilenet_v2_classifier


class ManifestDataset(Dataset):
    def __init__(self, manifest: Path, root: Path, transform: Any) -> None:
        with manifest.open("r", encoding="utf-8", newline="") as stream:
            self.rows = list(csv.DictReader(stream))
        if not self.rows:
            raise ValueError(f"Empty manifest: {manifest}")
        self.root = root
        self.transform = transform

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, int]:
        row = self.rows[index]
        path = self.root / Path(row["image_path"])
        with Image.open(path) as source:
            image = source.convert("RGB")
        if self.transform:
            image = self.transform(image)
        return image, int(row["label"])


class AspectPreservingLetterbox:
    """Fit the full tall bee crop to 224x224 without the pretrained center-crop loss."""

    def __init__(self, weights: MobileNet_V2_Weights, size: int = 224) -> None:
        preset = weights.transforms()
        self.size = size
        self.mean = list(preset.mean)
        self.std = list(preset.std)
        self.normalize = transforms.Normalize(mean=self.mean, std=self.std)
        interpolation = preset.interpolation
        self.resample = {
            InterpolationMode.BILINEAR: Image.Resampling.BILINEAR,
            InterpolationMode.BICUBIC: Image.Resampling.BICUBIC,
            InterpolationMode.NEAREST: Image.Resampling.NEAREST,
            InterpolationMode.LANCZOS: Image.Resampling.LANCZOS,
        }[interpolation]
        self.padding_rgb = tuple(round(channel * 255) for channel in self.mean)

    def __call__(self, image: Image.Image) -> torch.Tensor:
        image = image.convert("RGB")
        width, height = image.size
        scale = min(self.size / width, self.size / height)
        new_width = max(1, min(self.size, round(width * scale)))
        new_height = max(1, min(self.size, round(height * scale)))
        resized = image.resize((new_width, new_height), resample=self.resample)
        canvas = Image.new("RGB", (self.size, self.size), color=self.padding_rgb)
        canvas.paste(resized, ((self.size - new_width) // 2, (self.size - new_height) // 2))
        return self.normalize(transforms.ToTensor()(canvas))


def metrics_from_probs(labels: np.ndarray, positive_probs: np.ndarray) -> dict[str, float]:
    best_threshold = 0.5
    best_f1 = -1.0
    best_recall = -1.0
    for threshold in np.linspace(0.05, 0.95, 181):
        predicted = (positive_probs >= threshold).astype(np.int64)
        f1 = f1_score(labels, predicted, pos_label=1, zero_division=0)
        recall = recall_score(labels, predicted, pos_label=1, zero_division=0)
        if (f1, recall) > (best_f1, best_recall):
            best_f1, best_recall, best_threshold = float(f1), float(recall), float(threshold)
    predicted = (positive_probs >= best_threshold).astype(np.int64)
    try:
        auc = float(roc_auc_score(labels, positive_probs))
    except ValueError:
        auc = float("nan")
    return {
        "threshold": best_threshold,
        "accuracy": float(accuracy_score(labels, predicted)),
        "positive_precision": float(precision_score(labels, predicted, pos_label=1, zero_division=0)),
        "positive_recall": float(recall_score(labels, predicted, pos_label=1, zero_division=0)),
        "positive_f1": float(f1_score(labels, predicted, pos_label=1, zero_division=0)),
        "macro_f1": float(f1_score(labels, predicted, average="macro", zero_division=0)),
        "roc_auc": auc,
    }


@torch.inference_mode()
def evaluate_validation(model: nn.Module, loader: DataLoader, device: torch.device, criterion: nn.Module) -> tuple[float, dict[str, float]]:
    model.eval()
    losses: list[float] = []
    labels_all: list[np.ndarray] = []
    probs_all: list[np.ndarray] = []
    for images, labels in loader:
        images = images.to(device, non_blocking=device.type == "cuda")
        labels = labels.to(device, non_blocking=device.type == "cuda")
        logits = model(images)
        losses.append(float(criterion(logits, labels).item()))
        labels_all.append(labels.cpu().numpy())
        probs_all.append(torch.softmax(logits, dim=1)[:, 1].cpu().numpy())
    y_true = np.concatenate(labels_all)
    y_prob = np.concatenate(probs_all)
    return float(np.mean(losses)), metrics_from_probs(y_true, y_prob)


def train_epoch(model: nn.Module, loader: DataLoader, optimizer: torch.optim.Optimizer, criterion: nn.Module, device: torch.device) -> float:
    model.train()
    losses: list[float] = []
    for images, labels in loader:
        images = images.to(device, non_blocking=device.type == "cuda")
        labels = labels.to(device, non_blocking=device.type == "cuda")
        optimizer.zero_grad(set_to_none=True)
        logits = model(images)
        loss = criterion(logits, labels)
        loss.backward()
        optimizer.step()
        losses.append(float(loss.detach().item()))
    return float(np.mean(losses))


def run_phase(
    phase_name: str,
    epochs: int,
    patience: int,
    model: nn.Module,
    train_loader: DataLoader,
    val_loader: DataLoader,
    criterion: nn.Module,
    device: torch.device,
    output_dir: Path,
    history: list[dict[str, Any]],
    best_macro_f1: float,
    learning_rate: float,
    weight_decay: float,
) -> tuple[nn.Module, float]:
    optimizer = torch.optim.AdamW((parameter for parameter in model.parameters() if parameter.requires_grad), lr=learning_rate, weight_decay=weight_decay)
    stale_epochs = 0
    best_phase_f1 = -1.0
    for epoch in range(1, epochs + 1):
        started = time.monotonic()
        train_loss = train_epoch(model, train_loader, optimizer, criterion, device)
        val_loss, val_metrics = evaluate_validation(model, val_loader, device, criterion)
        record = {
            "phase": phase_name,
            "epoch": epoch,
            "train_loss": train_loss,
            "val_loss": val_loss,
            **{f"val_{key}": value for key, value in val_metrics.items()},
            "seconds": time.monotonic() - started,
        }
        history.append(record)
        print(json.dumps(record))

        score = val_metrics["macro_f1"]
        improved = score > best_macro_f1 + 1e-8
        if improved:
            best_macro_f1 = score
            stale_epochs = 0
            checkpoint = {
                "model_state_dict": model.state_dict(),
                "class_names": CLASS_NAMES,
                "best_validation": val_metrics,
                "validation_loss": val_loss,
                "phase": phase_name,
                "epoch": epoch,
                "torch_version": torch.__version__,
                "torchvision_version": torchvision.__version__,
            }
            torch.save(checkpoint, output_dir / "IT23183186_ModelA_MobileNetV2.pt")
            best_phase_f1 = score
        else:
            stale_epochs += 1
        if stale_epochs >= patience:
            print(f"Early stopping {phase_name} after {epoch} epochs without validation improvement.")
            break
    checkpoint = torch.load(output_dir / "IT23183186_ModelA_MobileNetV2.pt", map_location=device, weights_only=False)
    model.load_state_dict(checkpoint["model_state_dict"])
    return model, best_macro_f1


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepared-dir", type=Path, required=True, help="Output directory created by prepare_dataset.py")
    parser.add_argument("--output-dir", type=Path, required=True, help="Directory for checkpoints and reports")
    parser.add_argument("--seed", type=int, default=2026)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--workers", type=int, default=0, help="Use 0 for predictable Windows data loading")
    parser.add_argument("--cpu-threads", type=int, default=8)
    parser.add_argument("--head-epochs", type=int, default=5)
    parser.add_argument("--finetune-epochs", type=int, default=8)
    parser.add_argument("--patience", type=int, default=3)
    parser.add_argument("--finetune-blocks", type=int, default=2)
    args = parser.parse_args()

    args.prepared_dir = args.prepared_dir.resolve()
    args.output_dir = args.output_dir.resolve()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    seed_everything(args.seed)
    torch.set_num_threads(max(1, args.cpu_threads))
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Training device: {device}")

    weights = MobileNet_V2_Weights.IMAGENET1K_V1
    pretrained_transform = AspectPreservingLetterbox(weights)
    train_transform = transforms.Compose(
        [
            transforms.RandomHorizontalFlip(p=0.5),
            transforms.RandomRotation(degrees=5),
            transforms.ColorJitter(brightness=0.10, contrast=0.10, saturation=0.05, hue=0.02),
            pretrained_transform,
        ]
    )
    # Validation and test use letterboxing and pretrained normalization only.
    eval_transform = pretrained_transform
    train_set = ManifestDataset(args.prepared_dir / "manifests" / "train.csv", args.prepared_dir / "raw", train_transform)
    val_set = ManifestDataset(args.prepared_dir / "manifests" / "val.csv", args.prepared_dir / "raw", eval_transform)
    generator = torch.Generator().manual_seed(args.seed)
    train_loader = DataLoader(
        train_set,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=args.workers,
        pin_memory=device.type == "cuda",
        generator=generator,
    )
    val_loader = DataLoader(val_set, batch_size=args.batch_size, shuffle=False, num_workers=args.workers, pin_memory=device.type == "cuda")

    model = create_mobilenet_v2_classifier(pretrained=True)
    model.to(device)
    criterion = nn.CrossEntropyLoss()
    history: list[dict[str, Any]] = []
    best_macro_f1 = -1.0

    for parameter in model.features.parameters():
        parameter.requires_grad = False
    for parameter in model.classifier.parameters():
        parameter.requires_grad = True
    model, best_macro_f1 = run_phase(
        "head",
        args.head_epochs,
        args.patience,
        model,
        train_loader,
        val_loader,
        criterion,
        device,
        args.output_dir,
        history,
        best_macro_f1,
        learning_rate=1e-3,
        weight_decay=1e-4,
    )

    if args.finetune_epochs > 0:
        for parameter in model.features.parameters():
            parameter.requires_grad = False
        blocks = max(1, min(args.finetune_blocks, len(model.features)))
        for block in list(model.features.children())[-blocks:]:
            for parameter in block.parameters():
                parameter.requires_grad = True
        for parameter in model.classifier.parameters():
            parameter.requires_grad = True
        model, best_macro_f1 = run_phase(
            "fine_tune_last_blocks",
            args.finetune_epochs,
            args.patience,
            model,
            train_loader,
            val_loader,
            criterion,
            device,
            args.output_dir,
            history,
            best_macro_f1,
            learning_rate=1e-5,
            weight_decay=1e-4,
        )

    checkpoint = torch.load(args.output_dir / "IT23183186_ModelA_MobileNetV2.pt", map_location=device, weights_only=False)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()
    with (args.output_dir / "training_history.csv").open("w", encoding="utf-8", newline="") as stream:
        fields = sorted({key for record in history for key in record})
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(history)

    class_map = {str(index): name for index, name in enumerate(CLASS_NAMES)}
    write_json(args.output_dir / "class_map.json", class_map)
    preprocessing = {
        "architecture": "torchvision.models.mobilenet_v2",
        "pretrained_weights": "MobileNet_V2_Weights.IMAGENET1K_V1",
        "input_shape": [3, 224, 224],
        "evaluation_transform": "RGB; aspect-preserving bilinear fit to 224x224; padding filled with weight mean; ToTensor; exact ImageNet mean/std from MobileNet_V2_Weights.IMAGENET1K_V1",
        "pretrained_weight_interpolation": str(weights.transforms().interpolation),
        "imagenet_mean": pretrained_transform.mean,
        "imagenet_std": pretrained_transform.std,
        "letterbox_padding_rgb": list(pretrained_transform.padding_rgb),
        "training_only_augmentation": ["RandomHorizontalFlip(p=0.5)", "RandomRotation(5 degrees)", "ColorJitter(brightness=0.10, contrast=0.10, saturation=0.05, hue=0.02)"],
        "classes": CLASS_NAMES,
        "threshold_selected_using_validation_only": checkpoint["best_validation"]["threshold"],
    }
    write_json(args.output_dir / "preprocessing.json", preprocessing)
    training_config = {
        "seed": args.seed,
        "batch_size": args.batch_size,
        "workers": args.workers,
        "cpu_threads": args.cpu_threads,
        "head_epochs_max": args.head_epochs,
        "finetune_epochs_max": args.finetune_epochs,
        "early_stopping_patience": args.patience,
        "finetune_blocks": args.finetune_blocks,
        "device": str(device),
        "python_version": sys.version,
        "platform": platform.platform(),
        "numpy_version": np.__version__,
        "torch_version": torch.__version__,
        "torchvision_version": torchvision.__version__,
        "sklearn_version": __import__("sklearn").__version__,
        "best_validation": checkpoint["best_validation"],
        "best_phase": checkpoint["phase"],
        "best_epoch": checkpoint["epoch"],
        "train_manifest": str(args.prepared_dir / "manifests" / "train.csv"),
        "validation_manifest": str(args.prepared_dir / "manifests" / "val.csv"),
        "checkpoint": str(args.output_dir / "IT23183186_ModelA_MobileNetV2.pt"),
    }
    write_json(args.output_dir / "training_config.json", training_config)
    write_json(args.output_dir / "model_metadata.json", {
        "task": "binary image classification of individual bee crops",
        "dataset": "VarroaDataset",
        "output_class_order": CLASS_NAMES,
        "checkpoint_format": "PyTorch state_dict package",
        "test_set_used_during_training": False,
        "validation_selected_threshold": checkpoint["best_validation"]["threshold"],
    })
    print(json.dumps({"best_validation": checkpoint["best_validation"], "artifacts": str(args.output_dir)}, indent=2))


if __name__ == "__main__":
    main()
