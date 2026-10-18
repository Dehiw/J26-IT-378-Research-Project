"""Per-hive calibration experiment, on the features already extracted.

Each hive's features are standardised with that hive's own mean and standard
deviation. No labels are used, so this is what the sensor can do with
unlabelled audio from each hive. Then leave-one-hive-out runs with the same
Random Forest as the baseline.

Two variants are compared:
  baseline    raw features (same as train_baseline.py)
  calibrated  each hive standardised with its own unlabelled statistics

Each variant is reported over all 12 hives, and over the hives that contain
both classes. The training set is always all the other hives. Only the
reporting changes.

Outputs (results/):
  calibration_comparison.csv / .png   summary table for the slides
  calibration_per_hive.csv            per-hive accuracy and macro F1
  calibration_per_hive_bar.png        per-hive bar chart, baseline vs calibrated

Run:  python calibration_experiment.py   (about 10 minutes: 24 forest fits)
"""

import time

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from sklearn.metrics import accuracy_score, f1_score  # noqa: E402

import config  # noqa: E402
from train_baseline import load_features, metrics, new_forest  # noqa: E402

VARIANTS = ["baseline", "calibrated"]
SUBSETS = ["all 12 hives", "hives with both classes"]


def standardise_per_hive(X: np.ndarray, hive_id: np.ndarray) -> np.ndarray:
    """Z-score each hive's features with that hive's own mean and std (no labels)."""
    out = np.empty_like(X, dtype=np.float32)
    for hive in np.unique(hive_id):
        mask = hive_id == hive
        mean = X[mask].mean(axis=0)
        std = X[mask].std(axis=0)
        out[mask] = (X[mask] - mean) / (std + 1e-6)
    return out


def leave_one_hive_out(X, y, hive_id):
    """Per-hive rows plus the held-out predictions, in hive order."""
    rows, truth, pred, owner = [], [], [], []
    for hive in sorted(np.unique(hive_id)):
        held_out = hive_id == hive
        model = new_forest().fit(X[~held_out], y[~held_out])
        y_true = y[held_out]
        y_pred = model.predict(X[held_out])
        truth.append(y_true)
        pred.append(y_pred)
        owner.append(np.full(len(y_true), hive, dtype=object))
        rows.append(
            {
                "hive_id": hive,
                "n_test": int(held_out.sum()),
                "n_queen_present": int((y_true == 1).sum()),
                "n_queenless": int((y_true == 0).sum()),
                **metrics(y_true, y_pred),
            }
        )
    return pd.DataFrame(rows), np.concatenate(truth), np.concatenate(pred), np.concatenate(owner)


def summarise(per_hive: pd.DataFrame, truth, pred, owner, hives) -> dict:
    """Mean over hives, and pooled over all held-out predictions for those hives."""
    subset = per_hive[per_hive["hive_id"].isin(hives)]
    keep = np.isin(owner, list(hives))
    return {
        "n_hives": len(subset),
        "mean_accuracy": subset["accuracy"].mean(),
        "sd_accuracy": subset["accuracy"].std(ddof=1),
        "mean_macro_f1": subset["macro_f1"].mean(),
        "sd_macro_f1": subset["macro_f1"].std(ddof=1),
        "pooled_accuracy": accuracy_score(truth[keep], pred[keep]),
        "pooled_macro_f1": f1_score(truth[keep], pred[keep], average="macro"),
    }


def both_class_hives(per_hive: pd.DataFrame) -> list[str]:
    has_both = (per_hive["n_queen_present"] > 0) & (per_hive["n_queenless"] > 0)
    return per_hive.loc[has_both, "hive_id"].tolist()


def check_baseline_matches_saved(per_hive: pd.DataFrame) -> None:
    saved_path = config.RESULTS_DIR / "loho_per_hive.csv"
    if not saved_path.exists():
        print("  (no saved baseline table to compare with)")
        return
    saved = pd.read_csv(saved_path).set_index("hive_id")
    now = per_hive.set_index("hive_id")
    diff = (saved.loc[now.index, "accuracy"] - now["accuracy"]).abs().max()
    status = "matches" if diff < 1e-9 else f"differs by up to {diff:.4f}"
    print(f"  baseline rerun {status} the saved loho_per_hive.csv")


def save_comparison(summary_rows: list[dict]) -> None:
    table = pd.DataFrame(summary_rows)
    table.to_csv(config.RESULTS_DIR / "calibration_comparison.csv", index=False)

    shown = table.copy()
    for col in ["mean_accuracy", "sd_accuracy", "mean_macro_f1", "sd_macro_f1",
                "pooled_accuracy", "pooled_macro_f1"]:
        shown[col] = shown[col].map(lambda v: f"{v:.3f}")
    shown = shown[["variant", "hives", "n_hives", "mean_accuracy", "sd_accuracy",
                   "mean_macro_f1", "sd_macro_f1", "pooled_accuracy", "pooled_macro_f1"]]
    shown.columns = ["Variant", "Hives", "N", "Mean acc", "SD acc",
                     "Mean macro F1", "SD F1", "Pooled acc", "Pooled macro F1"]

    fig, ax = plt.subplots(figsize=(12, 0.6 * len(shown) + 1.4))
    ax.axis("off")
    grid = ax.table(cellText=shown.values, colLabels=shown.columns,
                    loc="center", cellLoc="center")
    grid.auto_set_font_size(False)
    grid.set_fontsize(10)
    grid.scale(1, 1.4)
    ax.set_title("Leave-one-hive-out: baseline vs per-hive calibration", pad=12)
    fig.tight_layout()
    fig.savefig(config.RESULTS_DIR / "calibration_comparison.png", dpi=150)
    plt.close(fig)


def save_per_hive_bars(merged: pd.DataFrame) -> None:
    labels = [
        h + ("" if b else " *") for h, b in zip(merged["hive_id"], merged["both_classes"])
    ]
    x = np.arange(len(merged))
    width = 0.38
    fig, axes = plt.subplots(2, 1, figsize=(12, 7.5), sharex=True)
    for ax, metric, title in zip(
        axes, ["accuracy", "macro_f1"], ["Accuracy", "Macro F1"]
    ):
        ax.bar(x - width / 2, merged[f"baseline_{metric}"], width, label="baseline")
        ax.bar(x + width / 2, merged[f"calibrated_{metric}"], width, label="calibrated")
        ax.axhline(0.5, color="grey", linewidth=0.8, linestyle="--")
        ax.set_ylim(0, 1.15)
        ax.set_yticks([0, 0.2, 0.4, 0.6, 0.8, 1.0])
        ax.set_ylabel(title)
        ax.legend(loc="upper center", ncol=2, frameon=False)
    axes[-1].set_xticks(x)
    axes[-1].set_xticklabels(labels, rotation=45, ha="right")
    axes[0].set_title(
        "Per held-out hive, baseline vs per-hive calibration "
        "(* = single class, excluded from the both-class summary)"
    )
    fig.tight_layout()
    fig.savefig(config.RESULTS_DIR / "calibration_per_hive_bar.png", dpi=150)
    plt.close(fig)


def main() -> None:
    config.RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    data = load_features()
    X, y, hive_id = data["X"], data["y"], data["hive_id"]
    print(f"Loaded {len(y)} clips, {X.shape[1]} features, {len(np.unique(hive_id))} hives")

    results = {}
    for variant in VARIANTS:
        features = X if variant == "baseline" else standardise_per_hive(X, hive_id)
        print(f"\nLeave-one-hive-out: {variant}")
        started = time.time()
        per_hive, truth, pred, owner = leave_one_hive_out(features, y, hive_id)
        print(f"  done in {(time.time() - started) / 60:.1f} min")
        results[variant] = (per_hive, truth, pred, owner)
        if variant == "baseline":
            check_baseline_matches_saved(per_hive)

    base_hives = results["baseline"][0]
    per_hive_base = base_hives
    both = both_class_hives(per_hive_base)
    all_hives = per_hive_base["hive_id"].tolist()

    summary_rows = []
    for variant in VARIANTS:
        per_hive, truth, pred, owner = results[variant]
        for subset_name, hives in [("all 12 hives", all_hives), ("hives with both classes", both)]:
            summary_rows.append(
                {"variant": variant, "hives": subset_name,
                 **summarise(per_hive, truth, pred, owner, hives)}
            )
    save_comparison(summary_rows)
    print("\nSummary")
    print(pd.DataFrame(summary_rows).round(4).to_string(index=False))

    merged = base_hives[["hive_id", "n_test"]].copy()
    merged["both_classes"] = merged["hive_id"].isin(both)
    for variant in VARIANTS:
        per_hive = results[variant][0].set_index("hive_id")
        merged[f"{variant}_accuracy"] = merged["hive_id"].map(per_hive["accuracy"])
        merged[f"{variant}_macro_f1"] = merged["hive_id"].map(per_hive["macro_f1"])
    merged.to_csv(config.RESULTS_DIR / "calibration_per_hive.csv", index=False)
    save_per_hive_bars(merged)
    print(f"\nSaved calibration tables and charts to {config.RESULTS_DIR}")


if __name__ == "__main__":
    main()
