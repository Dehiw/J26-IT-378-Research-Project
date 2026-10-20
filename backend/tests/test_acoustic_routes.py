"""Route logic with an in-memory stand-in for Firestore (no network, no real data)."""

import io
import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
pytest.importorskip("librosa")
import soundfile as sf  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402
from app.routes import acoustic as route  # noqa: E402
from app.routes.auth import get_current_user_id  # noqa: E402
from app.services import acoustic_service as svc  # noqa: E402

svc.load_model()
needs_model = pytest.mark.skipif(not svc.is_loaded(), reason="ONNX model not present")


class _Snap:
    def __init__(self, data):
        self._d = data
        self.exists = data is not None

    def to_dict(self):
        return None if self._d is None else dict(self._d)


class _Doc:
    def __init__(self, store, key):
        self.store, self.key = store, key

    def get(self):
        return _Snap(self.store.get(self.key))

    def set(self, data):
        self.store[self.key] = dict(data)

    def update(self, data):
        self.store[self.key].update(data)


class _Query:
    def __init__(self, store, field, value):
        self.store, self.field, self.value = store, field, value

    def get(self):
        return [_Snap(d) for d in self.store.values() if d.get(self.field) == self.value]


class _Coll:
    def __init__(self, store):
        self.store = store

    def document(self, key):
        return _Doc(self.store, key)

    def where(self, field, op, value):
        return _Query(self.store, field, value)


class FakeDb:
    def __init__(self):
        self.data = {"hives": {"h1": {"user_id": "u1", "apiary_id": "a1"}}, "acoustic_results": {}}

    def collection(self, name):
        return _Coll(self.data.setdefault(name, {}))


@pytest.fixture()
def client(monkeypatch):
    fake = FakeDb()
    monkeypatch.setattr(route, "db", fake)
    user = {"id": "u1"}
    app.dependency_overrides[get_current_user_id] = lambda: user["id"]
    c = TestClient(app)
    c.fake, c.user = fake, user
    yield c
    app.dependency_overrides.clear()


def _wav(seconds=4):
    t = np.arange(16000 * seconds) / 16000
    buf = io.BytesIO()
    sf.write(buf, (0.2 * np.sin(2 * np.pi * 200 * t)).astype(np.float32), 16000, format="WAV", subtype="PCM_16")
    return buf.getvalue()


def _post(client, hive="h1", data=None):
    return client.post(
        "/api/v1/acoustic/analyze",
        data={"hive_id": hive, "source": "upload"},
        files={"audio": ("a.wav", data or _wav(), "audio/wav")},
    )


@needs_model
def test_analyze_save_history_flow(client):
    r = _post(client)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["label"] in ("normal", "queenless") and body["saved"] is False
    assert body["clip_count"] == 2 and len(body["clip_probabilities"]) == 2
    stored = client.fake.data["acoustic_results"][body["id"]]
    assert stored["apiary_id"] == "a1" and stored["user_id"] == "u1"
    assert "audio" not in stored

    assert client.get("/api/v1/acoustic/history?hive_id=h1").json()["results"] == []
    assert client.post(f"/api/v1/acoustic/results/{body['id']}/save").json()["saved"] is True
    hist = client.get("/api/v1/acoustic/history?hive_id=h1").json()["results"]
    assert [h["id"] for h in hist] == [body["id"]]
    assert client.get("/api/v1/acoustic/history?hive_id=other").json()["results"] == []
    assert client.get(f"/api/v1/acoustic/results/{body['id']}").status_code == 200

    client.user["id"] = "u2"  # another user cannot see or save it
    assert client.get(f"/api/v1/acoustic/results/{body['id']}").status_code == 404
    assert client.post(f"/api/v1/acoustic/results/{body['id']}/save").status_code == 404
    assert client.get("/api/v1/acoustic/history").json()["results"] == []


@needs_model
def test_analyze_errors(client):
    assert _post(client, hive="nope").status_code == 404
    client.user["id"] = "u2"
    assert _post(client).status_code == 403
    client.user["id"] = "u1"
    short = _post(client, data=_wav(1))
    assert short.status_code == 400 and "too short" in short.json()["detail"]


def test_analyze_503_without_model(client, monkeypatch):
    monkeypatch.setattr(svc, "_session", None)
    monkeypatch.setenv("ACOUSTIC_MODEL_PATH", "missing.onnx")
    r = _post(client)
    assert r.status_code == 503 and r.json()["detail"] == "Acoustic model not available"
