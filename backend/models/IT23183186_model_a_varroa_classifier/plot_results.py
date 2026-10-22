"""Plot saved validation progress and existing final test outputs; never runs inference."""
import argparse
import csv
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def plot_results(model_dir, training_log=None):
    model_dir = Path(model_dir)
    output = model_dir / "graphs"
    output.mkdir(parents=True, exist_ok=True)
    history_path = model_dir / "training_history.csv"
    records = []
    if history_path.is_file():
        with history_path.open(encoding="utf-8", newline="") as stream:
            records = list(csv.DictReader(stream))
    elif training_log and Path(training_log).is_file():
        for line in Path(training_log).read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                record = json.loads(line)
                if isinstance(record, dict) and "epoch" in record and "val_accuracy" in record:
                    records.append(record)
            except json.JSONDecodeError:
                pass
    complete = (model_dir / "training_config.json").is_file() and history_path.is_file()
    status = "Completed training / validation" if complete else "PRELIMINARY validation progress - training completion unverified"
    if records:
        x = np.arange(1, len(records) + 1)
        fig, axes = plt.subplots(1, 2, figsize=(12, 4.5), layout="constrained")
        for key, label in (("train_loss", "Training"), ("val_loss", "Validation")):
            axes[0].plot(x, [float(r[key]) for r in records], marker="o", label=label)
        axes[0].set(title="Loss", xlabel="Completed epochs across phases", ylabel="Cross-entropy")
        for key, label in (("val_accuracy", "Accuracy"), ("val_positive_recall", "Varroa recall"), ("val_macro_f1", "Macro F1")):
            axes[1].plot(x, [float(r[key]) for r in records], marker="o", label=label)
        axes[1].set(title="Validation metrics", xlabel="Completed epochs across phases", ylabel="Score", ylim=(0, 1))
        for axis in axes:
            axis.legend()
            axis.grid(alpha=.2)
            axis.set_xticks(x)
        fig.suptitle(status, fontsize=11)
        fig.savefig(output / "training_progress.png", dpi=180)
        plt.close(fig)
        last = records[-1]
        keys = ["val_accuracy", "val_positive_precision", "val_positive_recall", "val_positive_f1", "val_macro_f1", "val_roc_auc"]
        values = [float(last[k]) for k in keys]
        fig, axis = plt.subplots(figsize=(10, 5), layout="constrained")
        bars = axis.bar(["Accuracy", "Varroa\nprecision", "Varroa\nrecall", "Varroa F1", "Macro F1", "ROC-AUC"], values, color=["#426A5A", "#426A5A", "#BC8531", "#426A5A", "#426A5A", "#426A5A"])
        axis.bar_label(bars, labels=[f"{v:.3f}" for v in values], padding=4)
        axis.set(ylim=(0, 1.1), ylabel="Validation score", title=f"Latest completed epoch: {last['phase']} {last['epoch']}\n{status}")
        fig.savefig(output / "validation_metrics.png", dpi=180)
        plt.close(fig)
    report_path = model_dir / "evaluation" / "test_evaluation.json"
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.is_file() else None
    if report:
        matrix = np.array(report["confusion_matrix"])
        labels = report["confusion_matrix_labels_order"]
        fig, axis = plt.subplots(figsize=(6, 5), layout="constrained")
        display = axis.imshow(matrix, cmap="Blues")
        fig.colorbar(display, ax=axis)
        axis.set(xticks=range(len(labels)), yticks=range(len(labels)), xticklabels=labels, yticklabels=labels, xlabel="Predicted class", ylabel="Actual class", title="Untouched test set - confusion matrix")
        for row in range(len(labels)):
            for col in range(len(labels)):
                axis.text(col, row, str(matrix[row, col]), ha="center", va="center", color="white" if matrix[row, col] > matrix.max()/2 else "black")
        fig.savefig(output / "test_confusion_matrix.png", dpi=180)
        plt.close(fig)
        fig, axis = plt.subplots(figsize=(8, 5), layout="constrained")
        positions = np.arange(len(labels))
        for offset, metric in enumerate(("precision", "recall", "f1-score")):
            axis.bar(positions + (offset-1)*.23, [report["per_class"][label][metric] for label in labels], width=.23, label=metric)
        axis.set(xticks=positions, xticklabels=labels, ylim=(0, 1.1), ylabel="Test score", title=f"Test accuracy {report['accuracy']:.3f}")
        axis.legend()
        fig.savefig(output / "test_per_class_metrics.png", dpi=180)
        plt.close(fig)
        predictions = model_dir / "evaluation" / "test_predictions.csv"
        if predictions.is_file():
            with predictions.open(encoding="utf-8", newline="") as stream:
                rows = list(csv.DictReader(stream))
            truth = np.array([r["true_class"] == "varroa_positive" for r in rows])
            scores = np.array([float(r["positive_probability"]) for r in rows])
            if truth.any() and (~truth).any():
                order = np.argsort(-scores, kind="stable")
                boundaries = np.r_[np.where(np.diff(scores[order]))[0], len(scores)-1]
                tpr = np.r_[0, np.cumsum(truth[order])[boundaries] / truth.sum()]
                fpr = np.r_[0, np.cumsum(~truth[order])[boundaries] / (~truth).sum()]
                fig, axis = plt.subplots(figsize=(6, 5), layout="constrained")
                axis.plot(fpr, tpr, label=f"ROC-AUC {report['roc_auc']:.3f}")
                axis.plot([0, 1], [0, 1], "--", color="gray")
                axis.set(xlabel="False-positive rate", ylabel="Varroa-positive recall", title="Untouched test set - ROC", xlim=(0, 1), ylim=(0, 1))
                axis.legend()
                fig.savefig(output / "test_roc_curve.png", dpi=180)
                plt.close(fig)
    summary = {"training_complete_artifacts_present": complete, "epochs_recorded": len(records), "latest_validation": records[-1] if records else None, "final_test_evaluation_available": report is not None, "graphs": [p.name for p in output.glob("*.png")]}
    (output / "metrics_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--training-log", type=Path)
    args = parser.parse_args()
    plot_results(args.model_dir, args.training_log)
