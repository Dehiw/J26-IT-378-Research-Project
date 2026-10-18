"""Step 3: the one feature function, shared by training, prediction and the backend.

    features_from_wav(path)            -> np.ndarray, shape (N_FEATURES,)
    features_from_signal(samples, sr)  -> np.ndarray, shape (N_FEATURES,)

Steps: mono, resample to SAMPLE_RATE, log-mel (N_MELS bands), MFCC (N_MFCC),
then the mean and standard deviation of each coefficient over time.
Log-mel uses an absolute reference (power_to_db with ref=1.0), so the
loudness of the recording still matters. Do not change this without
retraining and re-exporting the model.
"""

import numpy as np
import librosa
import soundfile as sf

import config


def _feature_names() -> list[str]:
    names = []
    for kind, count in (("logmel", config.N_MELS), ("mfcc", config.N_MFCC)):
        for stat in ("mean", "std"):
            names += [f"{kind}_{i:02d}_{stat}" for i in range(count)]
    return names


FEATURE_NAMES = _feature_names()
N_FEATURES = len(FEATURE_NAMES)


def to_mono(samples: np.ndarray) -> np.ndarray:
    """Average channels, so the result is 1-D. Accepts (n,) or (n, channels)."""
    samples = np.asarray(samples, dtype=np.float32)
    if samples.ndim == 2:
        samples = samples.mean(axis=1)
    return samples


def features_from_signal(samples: np.ndarray, sr: int) -> np.ndarray:
    """Features for audio already in memory. `sr` is its sample rate."""
    y = to_mono(samples)
    if y.size == 0:
        raise ValueError("audio is empty")
    if sr != config.SAMPLE_RATE:
        y = librosa.resample(y, orig_sr=sr, target_sr=config.SAMPLE_RATE, res_type="soxr_hq")

    mel = librosa.feature.melspectrogram(
        y=y,
        sr=config.SAMPLE_RATE,
        n_fft=config.N_FFT,
        hop_length=config.HOP_LENGTH,
        n_mels=config.N_MELS,
        power=2.0,
    )
    log_mel = librosa.power_to_db(mel, ref=1.0)
    mfcc = librosa.feature.mfcc(S=log_mel, n_mfcc=config.N_MFCC)

    # Same order as FEATURE_NAMES: log-mel mean, log-mel std, MFCC mean, MFCC std.
    feats = np.concatenate(
        [
            log_mel.mean(axis=1),
            log_mel.std(axis=1),
            mfcc.mean(axis=1),
            mfcc.std(axis=1),
        ]
    )
    return feats.astype(np.float32)


def load_wav(path) -> tuple[np.ndarray, int]:
    """Read a WAV file as float32 samples and its sample rate."""
    samples, sr = sf.read(str(path), dtype="float32", always_2d=False)
    return samples, sr


def features_from_wav(path) -> np.ndarray:
    """Features for a WAV file on disk."""
    samples, sr = load_wav(path)
    return features_from_signal(samples, sr)
