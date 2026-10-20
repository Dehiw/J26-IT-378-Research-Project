"""Step 5: export the final model to ONNX and check it against scikit-learn.

The check runs the full path on real WAV clips: features.py on each file,
then scikit-learn and ONNX Runtime, and compares labels and probabilities.

Run:  python export_onnx.py
"""

import time

import joblib
import numpy as np
import onnxruntime as ort
import pandas as pd
from skl2onnx import to_onnx
from skl2onnx.common.data_types import FloatTensorType

import config
from extract_features import audio_path
from features import N_FEATURES, features_from_wav

PROB_TOLERANCE = 1e-4  # float32 ONNX versus float64 scikit-learn


def export(model) -> None:
    config.MODELS_DIR.mkdir(parents=True, exist_ok=True)
    onnx_model = to_onnx(
        model,
        initial_types=[("input", FloatTensorType([None, N_FEATURES]))],
        options={id(model): {"zipmap": False}},
        target_opset=17,
    )
    with open(config.ONNX_MODEL_PATH, "wb") as f:
        f.write(onnx_model.SerializeToString())
    size_mb = config.ONNX_MODEL_PATH.stat().st_size / 1e6
    print(f"  wrote {config.ONNX_MODEL_PATH.name} ({size_mb:.1f} MB)")


def check(model) -> None:
    manifest = pd.read_csv(config.MANIFEST_PATH)
    sample = manifest.sample(n=config.ONNX_CHECK_CLIPS, random_state=config.SEED)

    started = time.time()
    X = np.stack(
        [
            features_from_wav(audio_path(d, p))
            for d, p in zip(sample["dataset"], sample["file_path"])
        ]
    )
    print(f"  features for {len(X)} WAV clips in {time.time() - started:.1f} s")

    session = ort.InferenceSession(
        str(config.ONNX_MODEL_PATH), providers=["CPUExecutionProvider"]
    )
    onnx_labels, onnx_probs = session.run(None, {"input": X})

    sk_labels = model.predict(X)
    sk_probs = model.predict_proba(X)

    labels_match = int(np.sum(onnx_labels == sk_labels))
    max_diff = float(np.max(np.abs(onnx_probs - sk_probs)))
    print(f"  labels match: {labels_match}/{len(X)}")
    print(f"  largest probability difference: {max_diff:.2e} (limit {PROB_TOLERANCE:.0e})")

    if labels_match != len(X) or max_diff > PROB_TOLERANCE:
        raise SystemExit("ONNX and scikit-learn disagree. Do not use this model.")
    print("  PASS: ONNX Runtime matches scikit-learn")


def main() -> None:
    model = joblib.load(config.SKLEARN_MODEL_PATH)
    print("Exporting to ONNX")
    export(model)
    print(f"\nChecking {config.ONNX_CHECK_CLIPS} clips against scikit-learn")
    check(model)


if __name__ == "__main__":
    main()
