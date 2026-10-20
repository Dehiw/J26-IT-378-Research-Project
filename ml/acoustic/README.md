# Queen presence: acoustic baseline

A Random Forest baseline that predicts **queen present** or **queenless** from a
2-second hive recording. It is trained on the BeeTogether-style dataset (SBCM,
NUHIVE and TBON) and exported to ONNX for the backend.

This is a baseline. Read the results section before using it for anything.

## Folder contents

| File | Purpose |
|---|---|
| `config.py` | All settings: `DATA_ROOT`, sample size, features, model parameters |
| `prepare.py` | Combines the metadata and draws the balanced sample → `data/manifest.csv` |
| `features.py` | **The shared feature function** (wav → 168 features). The backend reuses it |
| `extract_features.py` | Runs `features.py` over the manifest → `data/features.npz` |
| `train_baseline.py` | Random 80/20 split, leave-one-hive-out, final model → `results/`, `models/` |
| `export_onnx.py` | Exports to `models/queen_baseline.onnx` and checks it against scikit-learn |
| `predict.py` | Predicts for any WAV file, using the ONNX model |
| `calibration_experiment.py` | Per-hive calibration experiment (see its section below) |
| `results/` | Confusion matrices, per-hive table, summary, calibration tables and charts (small, committed) |
| `data/`, `models/`, `.venv/` | Ignored by git (see `.gitignore`) |

The dataset is read-only and is never copied into the repo. Audio is read from
`DATA_ROOT` at run time.

## Setup

Requires Python 3.13 on Windows. The code lives in `J26-IT-378-Research-Project/ml/acoustic`.
Run everything from that folder:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

Installing the packages took about 6 minutes on this machine.

Check `DATA_ROOT` in `config.py` points to the folder that holds the `.h5` files.

## Run

Run the steps in this order. All commands use the venv's Python.

```powershell
.\.venv\Scripts\python.exe prepare.py            # step 2: sample and check files
.\.venv\Scripts\python.exe extract_features.py   # step 3: features for 30,000 clips
.\.venv\Scripts\python.exe train_baseline.py     # step 4: both evaluations + final model
.\.venv\Scripts\python.exe export_onnx.py        # step 5: ONNX export + 100-clip check
.\.venv\Scripts\python.exe predict.py path\to\recording.wav        # step 6
.\.venv\Scripts\python.exe predict.py path\to\recording.wav --json # for scripts
```

`extract_features.py --limit 500` does a quick timing check without saving.

`predict.py` takes any sample rate. Recordings are resampled to 8 kHz. Long
recordings are split into 2 s windows, and the probabilities are averaged.

## Data sampling (step 2)

- **Sources:** SBCM (213,000 clips), NUHIVE (169,044), TBON (10,334 with bee
  presence = 1). BAD is excluded because it has no queen labels.
- **Hive id:** dataset plus hive number, for example `SBCM-1`. Each SBCM hive
  number maps to one device, so the hive id is unambiguous.
- **Sample:** 30,000 clips, seed 42. 15,000 per label. Within each label the
  clips are spread evenly over the hives that have data, and a hive with fewer
  clips than its share gives all of them.
- **File check:** all 30,000 sampled files exist under `DATA_ROOT`.

Per-hive counts (from `prepare.py`):

| Hive | Queenless | Queen present | Total |
|---|---:|---:|---:|
| NUHIVE-1 | 1,948 | 1,748 | 3,696 |
| NUHIVE-3 | 1,948 | 1,748 | 3,696 |
| SBCM-1 | 1,948 | 1,748 | 3,696 |
| SBCM-3 | 1,947 | 1,748 | 3,695 |
| SBCM-4 | 1,947 | 1,748 | 3,695 |
| SBCM-5 | 1,947 | 1,748 | 3,695 |
| TBON-1 | 981 | 1,748 | 2,729 |
| TBON-2 | 1,947 | 321 | 2,268 |
| TBON-3 | 6 | 0 | 6 |
| TBON-4 | 0 | 1,748 | 1,748 |
| TBON-5 | 381 | 0 | 381 |
| TBON-6 | 0 | 695 | 695 |

TBON-3 has only 6 clips in the whole source, so it is nearly empty.

## Features (step 3)

`features.py` converts a signal to 168 numbers:

1. Average to mono, resample to 8 kHz if needed.
2. Log-mel spectrogram with 64 bands (`power_to_db`, absolute reference, so loudness counts).
3. MFCC with 20 coefficients, computed from the log-mel.
4. Mean and standard deviation over time of each of the 84 coefficients.

Order: log-mel mean (64), log-mel std (64), MFCC mean (20), MFCC std (20). The
names are in `features.FEATURE_NAMES`.

Changing any of this means retraining and re-exporting the model.

## Results

### Evaluation (a): random 80/20 split

Stratified by label, seed 42. Train 24,000, test 6,000.

- Accuracy **0.949**, macro F1 **0.949**
- Confusion matrix: `results/random_split_confusion.png`

### Evaluation (b): leave-one-hive-out

Train on all other hives, test on the held-out hive. Macro F1 uses the labels
present in that hive's truth and predictions, which is scikit-learn's default.

| Held-out hive | Clips | Accuracy | Macro F1 | One class only |
|---|---:|---:|---:|:---:|
| NUHIVE-1 | 3,696 | 0.658 | 0.658 | |
| NUHIVE-3 | 3,696 | 0.741 | 0.740 | |
| SBCM-1 | 3,696 | 0.482 | 0.347 | |
| SBCM-3 | 3,695 | 0.581 | 0.558 | |
| SBCM-4 | 3,695 | 0.442 | 0.402 | |
| SBCM-5 | 3,695 | 0.468 | 0.326 | |
| TBON-1 | 2,729 | 0.873 | 0.862 | |
| TBON-2 | 2,268 | 0.340 | 0.275 | |
| TBON-3 | 6 | 0.000 | 0.000 | yes |
| TBON-4 | 1,748 | 0.366 | 0.268 | yes |
| TBON-5 | 381 | 0.333 | 0.250 | yes |
| TBON-6 | 695 | 0.863 | 0.463 | yes |
| **Mean over 12 hives** | | **0.512** (sd 0.250) | **0.429** (sd 0.241) | |

- Pooled over all held-out predictions: accuracy 0.566, macro F1 0.547.
- Files: `results/loho_per_hive.csv`, `results/loho_per_hive.png`, `results/loho_pooled_confusion.png`, `results/summary.csv`.

### Reading the results

- **The random split overstates the result.** Clips from the same recording
  and the same hive are almost identical, so a random split lets the model
  recognise a hive rather than learn queen presence. Hive-level performance is
  close to chance for several hives (mean 51%, against a 50% baseline for a
  balanced test set).
- **The TBON labels are almost confounded with the hive.** TBON-4 and TBON-6
  contain only queen-present clips. TBON-5 contains only queenless clips. For
  these, accuracy is the number that means something. Macro F1 for a
  single-class hive is not comparable with the others.
- **TBON-2 scores below chance** (0.34): it is 86% queenless, so the model's
  queen-present predictions for it are mostly wrong.
- **Domain gap.** The dataset recordings come from fixed hive microphones. The
  app records on a phone. None of the evaluations here use phone recordings,
  so the app's accuracy is unknown.

Do not present the 94.9% figure as the model's accuracy. The fair estimate for
an unseen hive is the leave-one-hive-out result, about 51% accuracy, with large
spread between hives.

## Per-hive calibration experiment

Question: if each hive's features are standardised with that hive's own
mean and standard deviation, does leave-one-hive-out improve? The same
Random Forest, the same 168 features, and the same 12 hives are used.
No labels are used for the standardisation. Script: `calibration_experiment.py`
(about 10 minutes: 24 forest fits).

| Variant | Hives | Mean acc (SD) | Mean macro F1 (SD) | Pooled acc | Pooled macro F1 |
|---|---|---|---|---|---|
| Baseline | all 12 | 0.512 (0.250) | 0.429 (0.241) | 0.566 | 0.547 |
| Calibrated | all 12 | 0.509 (0.178) | 0.447 (0.189) | 0.551 | 0.544 |
| Baseline | 8 with both classes | 0.573 (0.176) | 0.521 (0.216) | 0.575 | 0.559 |
| Calibrated | 8 with both classes | 0.543 (0.153) | 0.524 (0.172) | 0.549 | 0.545 |

- The 8 "both classes" hives are NUHIVE-1, NUHIVE-3, SBCM-1, SBCM-3, SBCM-4,
  SBCM-5, TBON-1 and TBON-2. TBON-3 (6 clips) and TBON-4, TBON-5 and TBON-6
  (one class each) are left out of that summary. They still count in the
  all-12 row.
- The training set is always the other hives, so only the reporting changes.
- The baseline rerun in this script matches the earlier table to within
  0.0005 accuracy. The earlier per-hive numbers are not bit-identical.

Per hive, calibration helps some hives and hurts others. NUHIVE-1 goes from
0.66 to 0.76, and SBCM-5 from 0.47 to 0.61. NUHIVE-3 goes from 0.74 to 0.56,
and TBON-1 from 0.87 to 0.71. The spread between hives falls, but the average
does not rise.

Files: `results/calibration_comparison.csv` and `.png` (summary table),
`results/calibration_per_hive.csv`, and `results/calibration_per_hive_bar.png`
(baseline and calibrated bars per hive).

**Why this matches the sensor:** the IoT sensor can record unlabelled audio
from a hive first, and compute that hive's statistics before any label exists.
Standardising with those statistics puts a new hive on a similar scale to the
training hives, without needing a single labelled clip from it.

**Limitation:** a hive's mean and standard deviation depend on its class mix.
A hive that is mostly queenless has a different average from one that is
mostly queen-present. Standardising each hive removes part of that difference,
so the effect on the mean depends on each hive's class mix. The TBON hives,
which are almost all one class, show this most clearly.

## Model and export (steps 4–5)

- Random Forest: 200 trees, `min_samples_leaf=2`, seed 42. Trained on all 30,000 clips.
- `models/queen_baseline.joblib` (scikit-learn, 54 MB) and
  `models/queen_baseline.onnx` (ONNX, 27 MB). Both are git-ignored.
- ONNX check: 100 random WAV clips, run through `features.py`. Labels match
  100/100. Largest probability difference 4.9e-7 (limit 1e-4). **PASS.**

ONNX input is `input` (float32, shape `[N, 168]`), with outputs `label` and
`probabilities` (`[N, 2]`, column 1 = queen present). The feature order must
match `features.FEATURE_NAMES`.

## Timings

Measured on this machine (Windows 11, Python 3.13):

| Step | Time |
|---|---|
| Venv and package install | about 6 min |
| `prepare.py` | 3 s |
| `extract_features.py` (30,000 clips) | 6.3 min (about 80 clips/s) |
| `train_baseline.py`: random split | 53 s |
| `train_baseline.py`: leave-one-hive-out (12 fits) | 11 min |
| `train_baseline.py`: final model | 41 s |
| `export_onnx.py` (export and 100-clip check) | not timed separately (100 clips: 3.6 s of feature extraction) |
| `predict.py` on an 8 s, 16 kHz file | about 15 s wall time, mostly library import and startup |

## Running the model in the app

The Flutter app sends a WAV file to the backend. The backend runs the ONNX
model with the same `features.py` code and returns **Queen Present** (label
`normal`) or **Queenless** (label `queenless`). These are the only two classes.
Nothing is faked when `AcousticConfig.useRealModel` is true. If the backend or
the model is missing, the app shows an error instead of a result.

### Start the backend

From the repo root (PowerShell):

```powershell
cd backend
.\venv\Scripts\python.exe -m uvicorn app.main:app --reload
```

Open `http://127.0.0.1:8000/api/v1/acoustic/model-info`. It must show
`"model_loaded": true`. The model loads on the first acoustic request (this call
includes it), so the first call takes a few seconds. Then run the app from `frontend/`
(`flutter run -d windows`), log in, open the Acoustic tab, pick a hive and
upload one of the test clips or record a sound.

### Running on another laptop

1. Copy `queen_baseline.onnx` into `ml/acoustic/models/` (it is not in git), or
   set `ACOUSTIC_MODEL_PATH` to where the file is.
2. Install the packages into the backend venv:

   ```powershell
   cd backend
   .\venv\Scripts\python.exe -m pip install -r requirements.txt
   .\venv\Scripts\python.exe -m pip install -r requirements-acoustic.txt
   ```

3. Put `firebase-service-account.json` in `backend/` (not in git).
4. Start with `.\venv\Scripts\python.exe -m uvicorn app.main:app --reload`.

Without the model file the backend still starts, and `/analyze` returns 503
"Acoustic model not available".

### Test clips

`test_clips/` holds 8 clips of 2 s each, with their true labels and the model's
predictions in `test_clips/test_clips.csv`. Regenerate them with
`make_test_clips.py`.

| File | Hive | True label | Model prediction | Queen-present probability | Correct |
|---|---|---|---|---:|---|
| test_01.wav | SBCM-5 | queenless | queenless | 0.208 | yes |
| test_02.wav | SBCM-3 | queenless | queenless | 0.257 | yes |
| test_03.wav | SBCM-4 | queenless | queenless | 0.081 | yes |
| test_04.wav | SBCM-4 | normal | queenless | 0.321 | NO |
| test_05.wav | SBCM-4 | normal | normal | 0.625 | yes |
| test_06.wav | SBCM-3 | normal | normal | 0.885 | yes |
| test_07.wav | SBCM-3 | queenless | normal | 0.689 | NO |
| test_08.wav | SBCM-5 | normal | normal | 0.895 | yes |

How to read them:

- The clips are **not** in the 30,000-clip training sample (`data/manifest.csv`),
  so the model did not see these exact clips.
- They **do** come from the same 12 hives as the training data, and clips from
  one hive are very similar. On a sample of 180 such clips the model scored
  94% accuracy, the same optimistic level as the random 80/20 split. This is
  **not** what to expect on a new hive.
- The fair estimate for an unseen hive is the leave-one-hive-out result: about
  **51% accuracy**, ranging from 34% to 87% by hive.
- `test_04.wav` and `test_07.wav` are predicted wrongly. They are kept on
  purpose.
- Phone recordings were never part of any evaluation, so accuracy on live
  recordings is unknown. The app labels the result "Experimental AI model,
  accuracy is limited on new hives".

### Backend tests

```powershell
cd backend
.\venv\Scripts\python.exe -m pytest tests -v -s
```

`test_acoustic_parity.py` checks that the backend's 168 features equal
`features.py` and that its predictions equal `predict.py`.

## Limits and next steps

- The model is a baseline. The random-split number should not be quoted as accuracy.
- Hive-level accuracy varies widely (0.34 to 0.87). More hives, and hives with both labels, would make the estimate firmer.
- Test on real recordings from the app's phone microphone before using the result in the app.
- The model is connected to the app through the backend (see "Running the model in the app"). The app has not been tested with phone recordings.
