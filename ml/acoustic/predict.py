"""Step 6: predict queen presence for any WAV file.

Uses the ONNX model and the same features.py function as training, so the
result matches what the backend will get. Works with any sample rate (the
app's 16 kHz recordings are resampled to the model rate).

Long recordings are split into CLIP_SECONDS windows. The probability is the
average over the windows. A final partial window is used only if it is at
least half a window long. A file shorter than one window is used as it is.

Run:  python predict.py path\\to\\recording.wav
      python predict.py path\\to\\recording.wav --json
"""

import argparse
import json

import numpy as np
import onnxruntime as ort

import config
from features import features_from_signal, load_wav


def split_windows(samples: np.ndarray, sr: int) -> list[np.ndarray]:
    size = int(round(config.CLIP_SECONDS * sr))
    if len(samples) <= size:
        return [samples]
    windows = [samples[i : i + size] for i in range(0, len(samples) - size + 1, size)]
    rest = samples[len(windows) * size :]
    if len(rest) >= size // 2:
        windows.append(rest)
    return windows


def predict_file(path, session) -> dict:
    samples, sr = load_wav(path)
    if samples.ndim == 2:
        samples = samples.mean(axis=1)
    windows = split_windows(samples, sr)

    X = np.stack([features_from_signal(w, sr) for w in windows])
    _, probs = session.run(None, {"input": X})
    queen_prob = float(probs[:, 1].mean())

    return {
        "file": str(path),
        "prediction": config.LABEL_NAMES[int(queen_prob >= 0.5)],
        "queen_present_probability": round(queen_prob, 4),
        "windows": len(windows),
        "window_seconds": round(len(windows[0]) / sr, 2),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("wav", nargs="+", help="one or more WAV files")
    parser.add_argument("--json", action="store_true", help="print JSON")
    args = parser.parse_args()

    session = ort.InferenceSession(
        str(config.ONNX_MODEL_PATH), providers=["CPUExecutionProvider"]
    )
    results = [predict_file(path, session) for path in args.wav]

    if args.json:
        print(json.dumps(results if len(results) > 1 else results[0], indent=2))
        return
    for r in results:
        queen = r["queen_present_probability"]
        print(f"{r['file']}")
        print(f"  {r['prediction']}  (queen-present probability {queen:.2f})")
        print(f"  {r['windows']} window(s) of about {r['window_seconds']} s")


if __name__ == "__main__":
    main()
