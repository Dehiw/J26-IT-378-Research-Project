"""Parity of the backend acoustic code with models/IT23139930_Model/acoustic.

Run from backend/:  venv\\Scripts\\python.exe -m pytest tests -v -s
Tests that need the ONNX model or the dataset skip when those are missing.
"""

import io
import sys
from pathlib import Path

import numpy as np
import pytest

BACKEND = Path(__file__).resolve().parents[1]
ML_DIR = BACKEND / "models" / "IT23139930_Model" / "acoustic"
sys.path.insert(0, str(BACKEND))

pytest.importorskip("librosa")
pytest.importorskip("soundfile")
ort = pytest.importorskip("onnxruntime")
import soundfile as sf  # noqa: E402

from app.services import acoustic_service as svc  # noqa: E402

MODEL = svc.model_path()
needs_model = pytest.mark.skipif(not MODEL.is_file(), reason="ONNX model not present")


@pytest.fixture(scope="module")
def ml():
    """Model-folder modules (features, predict, config), imported from ML_DIR."""
    sys.path.insert(0, str(ML_DIR))
    try:
        import config, features, predict  # noqa: E401
        return config, features, predict
    finally:
        sys.path.remove(str(ML_DIR))


@pytest.fixture(scope="module")
def dataset_wavs(ml):
    config, _, _ = ml
    import csv
    import random

    if not config.MANIFEST_PATH.is_file():
        pytest.skip("manifest not available")
    with open(config.MANIFEST_PATH, newline="") as f:
        rows = random.Random(7).sample(list(csv.DictReader(f)), 5)
    paths = [config.DATA_ROOT / r["dataset"] / r["file_path"] for r in rows]
    if not all(p.is_file() for p in paths):
        pytest.skip("dataset audio not available")
    return paths


def test_feature_parity(ml, dataset_wavs):
    _, features, _ = ml
    worst = 0.0
    for path in dataset_wavs:
        samples, sr = features.load_wav(path)
        a = features.features_from_signal(samples, sr)
        b = svc._features_from_signal(samples, sr)
        assert a.shape == b.shape == (168,)
        worst = max(worst, float(np.max(np.abs(a - b))))
    print(f"\nfeature max abs difference over {len(dataset_wavs)} clips: {worst:.3e}")
    assert worst == 0.0


@needs_model
def test_prediction_matches_predict_py(ml, dataset_wavs, tmp_path):
    config, features, predict = ml
    session = ort.InferenceSession(str(MODEL), providers=["CPUExecutionProvider"])

    # Single clips, plus one longer WAV (3 clips glued together, 6 s, multiple windows).
    files = list(dataset_wavs)
    parts = [features.load_wav(p) for p in dataset_wavs[:3]]
    long_sr = parts[0][1]
    long_wav = tmp_path / "long.wav"
    sf.write(long_wav, np.concatenate([s for s, _ in parts]), long_sr)
    files.append(long_wav)

    for path in files:
        expected = predict.predict_file(path, session)
        got = svc.analyze_bytes(Path(path).read_bytes())
        assert got["clip_count"] == expected["windows"], path
        assert got["queen_present_probability"] == pytest.approx(
            expected["queen_present_probability"], abs=1e-4
        )
        exp_label = "normal" if expected["prediction"] == "Queen present" else "queenless"
        assert got["label"] == exp_label, path
        print(f"{Path(path).name}: {got['label']} p_queen={got['queen_present_probability']} "
              f"clips={got['clip_count']} == predict.py {expected['prediction']}")


@needs_model
def test_app_style_wav_16k_mono(tmp_path):
    """What the Flutter app records: 16 kHz, mono, 16-bit PCM."""
    rng = np.random.default_rng(0)
    t = np.arange(16000 * 4) / 16000
    wave = 0.2 * np.sin(2 * np.pi * 220 * t) + 0.02 * rng.standard_normal(t.size)
    buf = io.BytesIO()
    sf.write(buf, wave.astype(np.float32), 16000, format="WAV", subtype="PCM_16")
    out = svc.analyze_bytes(buf.getvalue())
    assert out["clip_count"] == 2
    assert out["label"] in ("normal", "queenless")
    assert 0.5 <= out["confidence"] <= 1.0


@needs_model
def test_short_audio_rejected():
    buf = io.BytesIO()
    sf.write(buf, np.zeros(16000, dtype=np.float32) + 0.01, 16000, format="WAV", subtype="PCM_16")
    with pytest.raises(svc.AudioError, match="too short"):
        svc.analyze_bytes(buf.getvalue())


@needs_model
def test_garbage_audio_rejected():
    with pytest.raises(svc.AudioError):
        svc.analyze_bytes(b"not a wav file at all")


def test_missing_model_gives_503_error(monkeypatch, tmp_path):
    monkeypatch.setenv("ACOUSTIC_MODEL_PATH", str(tmp_path / "missing.onnx"))
    monkeypatch.setattr(svc, "_session", None)
    monkeypatch.setattr(svc, "_load_error", None)
    with pytest.raises(svc.ModelUnavailable, match="Acoustic model not available"):
        svc.analyze_bytes(b"x")
    info = svc.model_info()
    assert info["model_loaded"] is False and info["classes"] == ["normal", "queenless"]


# ---- audio quality -----------------------------------------------------------
def _wav_bytes(x, sr=16000, subtype="PCM_16"):
    buf = io.BytesIO()
    sf.write(buf, np.asarray(x, dtype=np.float32), sr, format="WAV", subtype=subtype)
    return buf.getvalue()


def _tone(seconds=3, sr=16000, amp=0.2, noise=0.02):
    rng = np.random.default_rng(1)
    t = np.arange(sr * seconds) / sr
    return amp * np.sin(2 * np.pi * 200 * t) + noise * rng.standard_normal(t.size)


@needs_model
def test_clip_files_are_not_poor():
    clips = sorted((ML_DIR / "test_clips").glob("test_*.wav"))
    assert len(clips) == 8
    for clip in clips:
        out = svc.analyze_bytes(clip.read_bytes())
        assert out["audio_quality"] != "poor", clip.name


def test_normal_phone_level_is_good_and_quiet_is_fair():
    assert svc._audio_quality(_tone(amp=0.2).astype(np.float32)) == "good"
    assert svc._audio_quality(_tone(amp=0.003, noise=0.0003).astype(np.float32)) == "fair"


@needs_model
def test_silent_wav_is_poor():
    out = svc.analyze_bytes(_wav_bytes(np.zeros(16000 * 3)))
    assert out["audio_quality"] == "poor"


@needs_model
def test_heavily_clipped_wav_is_poor():
    out = svc.analyze_bytes(_wav_bytes(np.clip(_tone(amp=3.0), -1.0, 1.0)))
    assert out["audio_quality"] == "poor"
