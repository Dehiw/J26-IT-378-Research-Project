"""Step 4: Random Forest baseline, evaluated two ways. Then the final model (step 5 input).

  a) random 80/20 split, stratified by label (for comparison with the paper)
  b) leave-one-hive-out: train on all other hives, test on the held-out hive

Outputs (results/):
  random_split_confusion.png, loho_pooled_confusion.png
  loho_per_hive.csv, loho_per_hive.png, summary.csv

Also saves models/queen_baseline.joblib trained on all sampled data.

Run:  python train_baseline.py
"""

import json
import time

import joblib
import matplotlib

matplotlib.use("Agg")  # save PNGs without opening windows
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from sklearn.ensemble import RandomForestClassifier  # noqa: E402
from sklearn.metrics import (  # noqa: E402
    ConfusionMatrixDisplay,
    accuracy_score,
    confusion_matrix,
    f1_score,
)
from sklearn.model_selection import train_test_split  # noqa: E402

import config  # noqa: E402

LABELS = [0, 1]
LABEL_TEXT = [config.LABEL_NAMES[label] for label in LABELS]


def load_features():
    data = np.load(config.FEATURES_PATH, allow_pickle=False)
    return {key: data[key] for key in data.files}


def new_forest() -> RandomForestClassifier:
    return RandomForestClassifier(**config.RF_PARAMS)


def save_confusion(y_true, y_pred, title: str, path) -> None:
    cm = confusion_matrix(y_true, y_pred, labels=LABELS)
    fig, ax = plt.subplots(figsize=(5, 4.5))
    ConfusionMatrixDisplay(cm, display_labels=LABEL_TEXT).plot(
        ax=ax, colorbar=False, values_format="d"
    )
    ax.set_title(title)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


def metrics(y_true, y_pred) -> dict:
    return {
        "accuracy": accuracy_score(y_true, y_pred),
        # Macro F1 is averaged over the labels that appear in the truth or the
        # predictions (scikit-learn's default). A single-class hive therefore
        # gets one F1 value, not two.
        "macro_f1": f1_score(y_true, y_pred, average="macro", zero_division=0),
    }


def random_split(data) -> dict:
    X, y = data["X"], data["y"]
    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=config.TEST_SIZE,
        stratify=y,
        random_state=config.SEED,
    )
    model = new_forest().fit(X_train, y_train)
    y_pred = model.predict(X_test)
    result = metrics(y_test, y_pred)
    result.update(n_train=len(y_train), n_test=len(y_test))
    save_confusion(
        y_test,
        y_pred,
        f"Random 80/20 split (acc {result['accuracy']:.3f}, F1 {result['macro_f1']:.3f})",
        config.RESULTS_DIR / "random_split_confusion.png",
    )
    return result


def leave_one_hive_out(data):
    X, y, hive_id, dataset = data["X"], data["y"], data["hive_id"], data["dataset"]
    rows = []
    pooled_true, pooled_pred = [], []

    hives = sorted(np.unique(hive_id))
    for n, hive in enumerate(hives, start=1):
        held_out = hive_id == hive
        started = time.time()
        model = new_forest().fit(X[~held_out], y[~held_out])
        y_true = y[held_out]
        y_pred = model.predict(X[held_out])

        pooled_true.append(y_true)
        pooled_pred.append(y_pred)
        present = sorted(np.unique(y_true))
        rows.append(
            {
                "hive_id": hive,
                "dataset": str(dataset[held_out][0]),
                "n_test": int(held_out.sum()),
                "n_queen_present": int((y_true == 1).sum()),
                "n_queenless": int((y_true == 0).sum()),
                "single_class": len(present) == 1,
                **metrics(y_true, y_pred),
            }
        )
        print(
            f"  [{n:2d}/{len(hives)}] {hive:10s} n={rows[-1]['n_test']:5d} "
            f"acc={rows[-1]['accuracy']:.3f} F1={rows[-1]['macro_f1']:.3f} "
            f"({time.time() - started:.0f}s)",
            flush=True,
        )

    per_hive = pd.DataFrame(rows)
    pooled_true = np.concatenate(pooled_true)
    pooled_pred = np.concatenate(pooled_pred)
    save_confusion(
        pooled_true,
        pooled_pred,
        "Leave-one-hive-out, all held-out predictions pooled",
        config.RESULTS_DIR / "loho_pooled_confusion.png",
    )
    summary = {
        "mean_accuracy": per_hive["accuracy"].mean(),
        "mean_macro_f1": per_hive["macro_f1"].mean(),
        "std_accuracy": per_hive["accuracy"].std(ddof=1),
        "std_macro_f1": per_hive["macro_f1"].std(ddof=1),
        "pooled_accuracy": accuracy_score(pooled_true, pooled_pred),
        "pooled_macro_f1": f1_score(pooled_true, pooled_pred, average="macro"),
        "n_hives": len(hives),
    }
    return per_hive, summary


def save_per_hive_table(per_hive: pd.DataFrame, summary: dict) -> None:
    columns = [
        "hive_id",
        "n_test",
        "n_queen_present",
        "n_queenless",
        "accuracy",
        "macro_f1",
        "single_class",
    ]
    shown = per_hive[columns].copy()
    shown["accuracy"] = shown["accuracy"].map("{:.3f}".format)
    shown["macro_f1"] = shown["macro_f1"].map("{:.3f}".format)
    shown["single_class"] = shown["single_class"].map({True: "yes", False: ""})

    mean_row = {
        "hive_id": "MEAN",
        "n_test": int(per_hive["n_test"].sum()),
        "n_queen_present": int(per_hive["n_queen_present"].sum()),
        "n_queenless": int(per_hive["n_queenless"].sum()),
        "accuracy": f"{summary['mean_accuracy']:.3f}",
        "macro_f1": f"{summary['mean_macro_f1']:.3f}",
        "single_class": "",
    }
    shown = pd.concat([shown, pd.DataFrame([mean_row])], ignore_index=True)
    shown.to_csv(config.RESULTS_DIR / "loho_per_hive.csv", index=False)

    fig, ax = plt.subplots(figsize=(9, 0.42 * len(shown) + 1.2))
    ax.axis("off")
    table = ax.table(
        cellText=shown.values,
        colLabels=["Held-out hive", "Clips", "Queen", "Queenless",
                   "Accuracy", "Macro F1", "Single class"],
        loc="center",
        cellLoc="center",
    )
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1, 1.3)
    ax.set_title("Leave-one-hive-out results", pad=12)
    fig.tight_layout()
    fig.savefig(config.RESULTS_DIR / "loho_per_hive.png", dpi=150)
    plt.close(fig)


def train_final(data) -> RandomForestClassifier:
    model = new_forest().fit(data["X"], data["y"])
    config.MODELS_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, config.SKLEARN_MODEL_PATH)
    print(f"  saved {config.SKLEARN_MODEL_PATH.name}")
    return model


def main() -> None:
    config.RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    data = load_features()
    print(f"Loaded {len(data['y'])} clips, {data['X'].shape[1]} features")
    print("Label counts:", dict(zip(*np.unique(data["y"], return_counts=True))))

    t0 = time.time()
    print("\n(a) Random 80/20 split")
    random_result = random_split(data)
    print(
        f"  accuracy {random_result['accuracy']:.4f}   "
        f"macro F1 {random_result['macro_f1']:.4f}   "
        f"(train {random_result['n_train']}, test {random_result['n_test']})"
    )
    random_seconds = time.time() - t0

    t1 = time.time()
    print("\n(b) Leave-one-hive-out")
    per_hive, loho = leave_one_hive_out(data)
    save_per_hive_table(per_hive, loho)
    loho_seconds = time.time() - t1
    print(
        f"  mean over {loho['n_hives']} hives: accuracy {loho['mean_accuracy']:.4f} "
        f"(sd {loho['std_accuracy']:.3f}), macro F1 {loho['mean_macro_f1']:.4f} "
        f"(sd {loho['std_macro_f1']:.3f})"
    )
    print(
        f"  pooled over all held-out predictions: accuracy "
        f"{loho['pooled_accuracy']:.4f}, macro F1 {loho['pooled_macro_f1']:.4f}"
    )

    print("\nFinal model on all sampled data")
    t2 = time.time()
    train_final(data)
    final_seconds = time.time() - t2

    summary_rows = [
        {"evaluation": "random_80_20", "mean_accuracy": random_result["accuracy"],
         "mean_macro_f1": random_result["macro_f1"], "sd_accuracy": np.nan,
         "sd_macro_f1": np.nan, "note": f"test n={random_result['n_test']}"},
        {"evaluation": "leave_one_hive_out", "mean_accuracy": loho["mean_accuracy"],
         "mean_macro_f1": loho["mean_macro_f1"], "sd_accuracy": loho["std_accuracy"],
         "sd_macro_f1": loho["std_macro_f1"],
         "note": f"{loho['n_hives']} hives; pooled acc {loho['pooled_accuracy']:.4f}, "
                 f"pooled F1 {loho['pooled_macro_f1']:.4f}"},
    ]
    pd.DataFrame(summary_rows).to_csv(config.RESULTS_DIR / "summary.csv", index=False)

    timings = {
        "random_split_seconds": round(random_seconds, 1),
        "leave_one_hive_out_seconds": round(loho_seconds, 1),
        "final_model_seconds": round(final_seconds, 1),
    }
    (config.RESULTS_DIR / "timings_train.json").write_text(json.dumps(timings, indent=2))
    print("\nTimings:", timings)
    print(f"Results written to {config.RESULTS_DIR}")


if __name__ == "__main__":
    main()
