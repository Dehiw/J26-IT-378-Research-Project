"""Pick test clips that are NOT in data/manifest.csv and write test_clips/.

Run:  .\.venv\Scripts\python.exe make_test_clips.py

Candidates are clips from the same 12 hives that were not in the 30,000-clip
training sample. The model never saw these exact clips, but it did see other
clips from the same hives, so results here are optimistic compared with a new
hive. The script keeps a mix of correct and wrong predictions on purpose.
"""

import csv
import shutil

import onnxruntime as ort
import pandas as pd

import config
from features import features_from_signal, load_wav
from prepare import load_all

OUT = config.ML_ROOT / "test_clips"
PER_HIVE_LABEL = 12      # candidates scored per hive and label
N_CORRECT_PER_CLASS = 3
N_WRONG = 2
SEED = 2026
NOTE = "not in training set, but same 12 hives as training: optimistic vs a new hive"
NAMES = {1: "normal", 0: "queenless"}  # app label names


def main() -> None:
    pool = load_all()
    train = pd.read_csv(config.MANIFEST_PATH)
    used = set(zip(train["dataset"], train["file_path"]))
    pool = pool[[(d, p) not in used for d, p in zip(pool["dataset"], pool["file_path"])]]
    print(f"{len(pool)} clips are not in the training manifest")

    cand = pd.concat(
        [g.sample(n=min(PER_HIVE_LABEL, len(g)), random_state=SEED)
         for _, g in pool.groupby(["hive_id", "label"])],
        ignore_index=True,
    )
    session = ort.InferenceSession(str(config.ONNX_MODEL_PATH), providers=["CPUExecutionProvider"])
    rows = []
    for r in cand.itertuples():
        path = config.DATA_ROOT / r.dataset / r.file_path
        if not path.is_file():
            continue
        samples, sr = load_wav(path)
        x = features_from_signal(samples, sr)[None, :]
        p_queen = float(session.run(None, {"input": x})[1][0, 1])
        pred = int(p_queen >= 0.5)
        rows.append({**r._asdict(), "path": path, "p_queen": p_queen, "pred": pred,
                     "duration": len(samples) / sr})
    df = pd.DataFrame(rows)
    df = df[df["duration"] >= 2.0]
    df["correct"] = df["pred"] == df["label"]
    print(f"scored {len(df)} clips, accuracy {df['correct'].mean():.3f}")
    print(df.groupby("hive_id")["correct"].mean().round(2).to_string())

    chosen = []
    for label in (1, 0):
        ok = df[(df["label"] == label) & df["correct"]]
        # one clip per hive, so the set is not 3 clips of the same hive
        ok = pd.concat([g.sample(1, random_state=SEED) for _, g in ok.groupby("hive_id")])
        chosen.append(ok.sample(n=N_CORRECT_PER_CLASS, random_state=SEED))
    wrong = df[~df["correct"]]
    wrong = pd.concat([g.sample(1, random_state=SEED) for _, g in wrong.groupby("label")])
    chosen.append(wrong.head(N_WRONG))
    sel = pd.concat(chosen).sample(frac=1.0, random_state=SEED).reset_index(drop=True)

    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()
    with open(OUT / "test_clips.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["file", "hive_id", "true_label", "model_prediction",
                    "queen_present_probability", "correct", "note"])
        for i, r in enumerate(sel.itertuples(), 1):
            name = f"test_{i:02d}.wav"
            shutil.copy(r.path, OUT / name)
            w.writerow([name, r.hive_id, NAMES[r.label], NAMES[r.pred],
                        f"{r.p_queen:.3f}", "yes" if r.correct else "NO", NOTE])
    size = sum(p.stat().st_size for p in OUT.iterdir())
    print(f"wrote {len(sel)} clips, {size / 1e6:.2f} MB, to {OUT}")


if __name__ == "__main__":
    main()
