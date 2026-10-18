"""Extract features for every clip in the manifest, using features.py.

Output: data/features.npz with X (n, N_FEATURES), y (labels), hive_id,
dataset and file_path. Audio is read from DATA_ROOT and never copied.

Run:  python extract_features.py            (all clips)
      python extract_features.py --limit 500  (quick timing check)
"""

import argparse
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np
import pandas as pd

import config
from features import N_FEATURES, features_from_wav


def audio_path(dataset: str, file_path: str):
    # Metadata "file path" is "SBCM/x.wav"; the audio is at DATA_ROOT/SBCM/SBCM/x.wav.
    return config.DATA_ROOT / dataset / file_path


def _work(args):
    index, dataset, file_path = args
    try:
        return index, features_from_wav(audio_path(dataset, file_path)), None
    except Exception as error:  # keep going; failures are reported at the end
        return index, None, f"{file_path}: {error}"


def extract(manifest: pd.DataFrame) -> tuple[np.ndarray, list[str]]:
    X = np.zeros((len(manifest), N_FEATURES), dtype=np.float32)
    failures = []
    jobs = [
        (i, dataset, file_path)
        for i, (dataset, file_path) in enumerate(
            zip(manifest["dataset"], manifest["file_path"])
        )
    ]

    total = len(jobs)
    started = time.time()
    chunk = max(1, total // 50)
    with ProcessPoolExecutor(max_workers=config.EXTRACT_WORKERS) as pool:
        for done, (index, vector, error) in enumerate(
            pool.map(_work, jobs, chunksize=64), start=1
        ):
            if error is None:
                X[index] = vector
            else:
                failures.append(error)
            if done % chunk == 0 or done == total:
                elapsed = time.time() - started
                rate = done / elapsed
                eta = (total - done) / rate
                print(
                    f"  {done:6d}/{total}  {100 * done / total:5.1f}%  "
                    f"{rate:6.1f} clips/s  ETA {eta / 60:5.1f} min",
                    flush=True,
                )
    return X, failures


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None, help="only the first N clips")
    args = parser.parse_args()

    manifest = pd.read_csv(config.MANIFEST_PATH)
    if args.limit:
        manifest = manifest.head(args.limit)
    print(f"Extracting {len(manifest)} clips from {config.MANIFEST_PATH.name}")

    started = time.time()
    X, failures = extract(manifest)
    elapsed = time.time() - started
    print(f"Done in {elapsed / 60:.1f} min")

    if failures:
        print(f"{len(failures)} clips failed, e.g.:")
        for line in failures[:5]:
            print("  ", line)
        raise SystemExit("Fix the failed clips before training.")

    if args.limit:
        print("Quick check only: features not saved.")
        return

    config.DATA_DIR.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(
        config.FEATURES_PATH,
        X=X,
        y=manifest["label"].to_numpy(dtype=np.int64),
        hive_id=manifest["hive_id"].to_numpy(dtype=str),
        dataset=manifest["dataset"].to_numpy(dtype=str),
        file_path=manifest["file_path"].to_numpy(dtype=str),
    )
    print(f"Saved {config.FEATURES_PATH} with X shape {X.shape}")


if __name__ == "__main__":
    main()
