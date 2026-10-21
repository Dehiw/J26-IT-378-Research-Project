"""Acoustic queen-status analysis: WAV bytes -> label, confidence, per-clip probabilities.

The feature code (`_features_from_signal`) is a copy of
backend/models/IT23139930_Model/acoustic/features.py (features_from_signal)
with the constants from its config.py inlined. It must not change behaviour: the model was
trained on those exact 168 numbers. backend/tests/test_acoustic_parity.py
checks the copy against the original.

librosa, soundfile and onnxruntime are imported lazily, so the backend starts
without them (or without the model file) and /analyze answers 503.
"""

import io
import logging
import os
import threading
from pathlib import Path

import numpy as np

logger = logging.getLogger("acoustic")

# ---- Settings (same values as IT23139930_Model/acoustic/config.py) -----------------------
SAMPLE_RATE = 8_000
N_FFT = 512
HOP_LENGTH = 128
N_MELS = 64
N_MFCC = 20
CLIP_SECONDS = 2.0
N_FEATURES = 2 * N_MELS + 2 * N_MFCC  # 168

MODEL_VERSION = "queen_baseline_rf_v1"
CLASSES = ["normal", "queenless"]  # queen present -> "normal"
CAVEAT = (
    "Experimental baseline. Accuracy on hives it has not seen is limited "
    "(about 51% in leave-one-hive-out tests) and phone recordings are untested."
)

# backend/app/services/acoustic_service.py -> parents[2] is backend/
_DEFAULT_MODEL = (
    Path(__file__).resolve().parents[2]
    / "models" / "IT23139930_Model" / "acoustic" / "models" / "queen_baseline.onnx"
)

# Audio quality thresholds. Silence and quiet use the app's dBFS numbers.
# Clipping differs from the app's -1 dBFS rule: the dataset clips are float
# WAVs standardised to unit variance (RMS 0 dBFS, peaks about 3.5), so a
# fixed level threshold flagged 37% of their samples as "clipped".
_SILENCE_FLOOR_DB = -60.0
_QUIET_RMS_DB = -45.0
_MAX_CLIPPED_RATIO = 0.001  # same ratio as the app's maxClippedSampleRatio
_MIN_CLIP_PEAK = 0.1        # clipping is only judged on a real signal


class AudioError(Exception):
    """The uploaded audio cannot be analysed (HTTP 400)."""


class ModelUnavailable(Exception):
    """Model file or audio libraries missing (HTTP 503)."""


def model_path() -> Path:
    return Path(os.getenv("ACOUSTIC_MODEL_PATH") or _DEFAULT_MODEL)


# ---- Model loading (once) ---------------------------------------------------
_session = None
_load_error: str | None = None
_lock = threading.Lock()


def load_model() -> None:
    """Load the ONNX session once. Never raises; records why it failed."""
    global _session, _load_error
    with _lock:
        if _session is not None:
            return
        path = model_path()
        if not path.is_file():
            _load_error = f"model file not found: {path}"
            return
        try:
            import librosa  # noqa: F401
            import soundfile  # noqa: F401
            import onnxruntime as ort

            _session = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
            _load_error = None
            logger.info("Acoustic model loaded from %s", path)
        except Exception as exc:  # missing library, corrupt model, ...
            _load_error = f"{type(exc).__name__}: {exc}"


def is_loaded() -> bool:
    return _session is not None


def model_info() -> dict:
    return {
        "model_loaded": is_loaded(),
        "model_version": MODEL_VERSION,
        "sample_rate": SAMPLE_RATE,
        "clip_seconds": CLIP_SECONDS,
        "classes": CLASSES,
        "n_features": N_FEATURES,
        "caveat": CAVEAT,
        "detail": None if is_loaded() else _load_error,
    }


# ---- Features: copy of IT23139930_Model/acoustic/features.py ------------------------------
def _features_from_signal(samples: np.ndarray, sr: int) -> np.ndarray:
    import librosa

    y = np.asarray(samples, dtype=np.float32)
    if y.ndim == 2:
        y = y.mean(axis=1)
    if y.size == 0:
        raise ValueError("audio is empty")
    if sr != SAMPLE_RATE:
        y = librosa.resample(y, orig_sr=sr, target_sr=SAMPLE_RATE, res_type="soxr_hq")

    mel = librosa.feature.melspectrogram(
        y=y, sr=SAMPLE_RATE, n_fft=N_FFT, hop_length=HOP_LENGTH, n_mels=N_MELS, power=2.0
    )
    log_mel = librosa.power_to_db(mel, ref=1.0)
    mfcc = librosa.feature.mfcc(S=log_mel, n_mfcc=N_MFCC)
    feats = np.concatenate(
        [log_mel.mean(axis=1), log_mel.std(axis=1), mfcc.mean(axis=1), mfcc.std(axis=1)]
    )
    return feats.astype(np.float32)


def _split_windows(samples: np.ndarray, sr: int) -> list[np.ndarray]:
    """Same rule as IT23139930_Model/acoustic/predict.py: 2 s windows, a last partial
    window only if it is at least half a window."""
    size = int(round(CLIP_SECONDS * sr))
    if len(samples) <= size:
        return [samples]
    windows = [samples[i : i + size] for i in range(0, len(samples) - size + 1, size)]
    rest = samples[len(windows) * size :]
    if len(rest) >= size // 2:
        windows.append(rest)
    return windows


def audio_levels(samples: np.ndarray) -> tuple[float, float]:
    """(rms_db, clipped_ratio). Clipped = samples pinned exactly at the peak
    value, the flat-top signature of clipping at any scale. A normal signal
    reaches its peak on only one or two samples."""
    if samples.size == 0:
        return -120.0, 0.0
    rms = float(np.sqrt(np.mean(np.square(samples))))
    rms_db = 20 * np.log10(rms) if rms > 0 else -120.0
    peak = float(np.max(np.abs(samples)))
    clipped = float(np.mean(np.abs(samples) == peak)) if peak >= _MIN_CLIP_PEAK else 0.0
    return rms_db, clipped


def _audio_quality(samples: np.ndarray) -> str:
    """"poor" only for near-silence or heavy clipping; quiet is "fair"."""
    rms_db, clipped = audio_levels(samples)
    if rms_db < _SILENCE_FLOOR_DB or clipped > _MAX_CLIPPED_RATIO:
        return "poor"
    if rms_db < _QUIET_RMS_DB:
        return "fair"
    return "good"


def read_audio(data: bytes) -> tuple[np.ndarray, int]:
    """Decode WAV (or other soundfile formats) to mono float32 and its rate."""
    import soundfile as sf

    try:
        samples, sr = sf.read(io.BytesIO(data), dtype="float32", always_2d=False)
    except Exception as exc:
        raise AudioError("Could not read the audio file. Please upload a valid WAV file.") from exc
    if samples.ndim == 2:
        samples = samples.mean(axis=1)
    return samples.astype(np.float32), int(sr)


def analyze_bytes(data: bytes) -> dict:
    """Run the full pipeline. Raises AudioError (400) or ModelUnavailable (503)."""
    load_model()
    if _session is None:
        raise ModelUnavailable("Acoustic model not available")
    if not data:
        raise AudioError("The audio file is empty.")

    samples, sr = read_audio(data)
    duration = len(samples) / sr if sr else 0.0
    if duration < CLIP_SECONDS:
        raise AudioError(
            f"Recording is too short ({duration:.1f} s). At least {CLIP_SECONDS:.0f} seconds are needed."
        )

    windows = _split_windows(samples, sr)
    X = np.stack([_features_from_signal(w, sr) for w in windows]).astype(np.float32)
    _, probs = _session.run(None, {"input": X})  # column 1 = queen present
    clip_queen = [round(float(p), 4) for p in probs[:, 1]]
    queen_prob = float(probs[:, 1].mean())

    if queen_prob >= 0.5:
        label, confidence = "normal", queen_prob
    else:
        label, confidence = "queenless", 1.0 - queen_prob

    return {
        "label": label,
        "confidence": round(confidence, 4),
        "queen_present_probability": round(queen_prob, 4),
        "clip_count": len(windows),
        "clip_probabilities": clip_queen,  # queen-present probability per clip
        "audio_quality": _audio_quality(samples),
        "duration_seconds": round(duration, 2),
        "model_version": MODEL_VERSION,
    }
