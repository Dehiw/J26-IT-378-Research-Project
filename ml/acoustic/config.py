"""All settings for the acoustic baseline. Change values here, not in the scripts."""

from pathlib import Path

# ---- Paths -----------------------------------------------------------------

# Read-only dataset. Metadata .h5 files sit here; audio is one level deeper:
#   metadata "file path" = "SBCM/x.wav"  ->  DATA_ROOT/SBCM/SBCM/x.wav
DATA_ROOT = Path(r"C:\Disk D\SLIIT\Reserch\DATASET\New folder\archive")

ML_ROOT = Path(__file__).resolve().parent
DATA_DIR = ML_ROOT / "data"          # manifest and features (git-ignored)
RESULTS_DIR = ML_ROOT / "results"    # small CSV/PNG outputs for slides (committed)
MODELS_DIR = ML_ROOT / "models"      # trained model files (git-ignored if large)

ONNX_MODEL_PATH = MODELS_DIR / "queen_baseline.onnx"
SKLEARN_MODEL_PATH = MODELS_DIR / "queen_baseline.joblib"
MANIFEST_PATH = DATA_DIR / "manifest.csv"
FEATURES_PATH = DATA_DIR / "features.npz"

# ---- Data sources ----------------------------------------------------------

# Dataset name -> metadata file (inside DATA_ROOT). BAD is excluded: it has
# no queen labels, so it cannot be used for training.
SOURCES = {
    "SBCM": "SBCM.h5",
    "NUHIVE": "NUHIVE.h5",
    "TBON": "TBON.h5",
}
METADATA_KEY = "bee_audio"

# TBON rows are used only when bee presence is 1 (a bee is in the clip).
TBON_BEE_PRESENCE_VALUE = 1

# Labels: 1 = queen present, 0 = queenless.
LABEL_NAMES = {0: "Queenless", 1: "Queen present"}

# ---- Sampling --------------------------------------------------------------

SEED = 42
TARGET_TOTAL = 30_000        # about this many clips in total
# Each label gets half of TARGET_TOTAL. Within a label, the clips are spread
# evenly over the hives that have data for that label.

# ---- Features --------------------------------------------------------------

SAMPLE_RATE = 8_000          # model input rate; other rates are resampled
N_FFT = 512                  # 64 ms window at 8 kHz
HOP_LENGTH = 128             # 16 ms hop
N_MELS = 64                  # log-mel bands
N_MFCC = 20                  # MFCC coefficients
CLIP_SECONDS = 2.0           # training clip length; long WAVs are split into these

# ---- Training --------------------------------------------------------------

TEST_SIZE = 0.2              # random split: 80% train, 20% test
RF_PARAMS = {
    "n_estimators": 200,
    "max_depth": None,
    "min_samples_leaf": 2,
    "n_jobs": -1,
    "random_state": SEED,
}

# ---- Export and checks -----------------------------------------------------

ONNX_CHECK_CLIPS = 100       # clips used to compare ONNX with scikit-learn
EXTRACT_WORKERS = None       # None = use all CPU cores
