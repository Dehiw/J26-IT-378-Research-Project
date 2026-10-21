"""IT23136274 colony health sensor anomaly route and model tests.

Firestore is replaced with SIMULATED documents (no network, no real data).
The model tests load the real saved Isolation Forest V2 file read-only.
"""

from datetime import datetime, timezone

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.routes import IT23136274_colony_health as route
from app.services.IT23136274_colony_health_service import (
    MODEL_PATH,
    ColonyHealthModelService,
    InvalidReadingError,
    validate_reading,
)

real_model = ColonyHealthModelService()
real_model.load_once()
needs_model = pytest.mark.skipif(not real_model.available, reason=str(real_model.status["message"]))


class _SimulatedDoc:
    """Stands in for a Firestore DocumentSnapshot from sensor_readings."""

    def __init__(self, data, doc_id="simulated-doc"):
        self._data, self.id = data, doc_id

    def to_dict(self):
        return dict(self._data)


def _simulated_reading(**overrides):
    data = {
        "hive_id": "HIVE_TEST",
        "temperature": 25.0,
        "humidity": 60.0,
        "weight": 1.0,
        "timestamp": datetime(2026, 10, 20, 12, 0, tzinfo=timezone.utc),
    }
    data.update(overrides)
    return data


def make_client(monkeypatch, docs=(), service=real_model):
    monkeypatch.setattr(route, "_run_query", lambda query: list(docs))
    monkeypatch.setattr(route, "_latest_query", lambda hive_id: None)
    app = FastAPI()
    app.include_router(route.router, prefix="/api/v1")
    app.state.colony_health_model_service = service
    return TestClient(app)


# ── Validation ─────────────────────────────────────────────────────

def test_validate_reading_preserves_order_and_converts_ints():
    assert validate_reading(30, 70.5) == (30.0, 70.5)


@pytest.mark.parametrize(
    "temperature, humidity",
    [
        (None, 50.0),
        (25.0, None),
        ("25", 50.0),
        (True, 50.0),
        (float("nan"), 50.0),
        (25.0, float("inf")),
        (-20.1, 50.0),
        (60.1, 50.0),
        (25.0, -0.1),
        (25.0, 100.1),
    ],
)
def test_validate_reading_rejects_bad_values(temperature, humidity):
    with pytest.raises(InvalidReadingError):
        validate_reading(temperature, humidity)


# ── Real saved model ───────────────────────────────────────────────

@needs_model
def test_real_model_returns_only_documented_labels():
    for temperature, humidity in [(20, 40), (25, 60), (30.1, 76.6), (35, 80), (28.3, 84.3)]:
        result = real_model.predict(temperature, humidity)
        assert result["model_prediction"] in (1, -1)
        assert result["status"] in ("Normal Sensor Pattern", "Inspection Recommended")
        assert "does not confirm colony health" in result["note"]
        assert not any("confidence" in key or "probab" in key for key in result)


@needs_model
def test_label_mapping_matches_prediction_value():
    result = real_model.predict(25.0, 60.0)
    expected = {
        1: ("Normal Sensor Pattern", "No unusual temperature/humidity pattern detected."),
        -1: (
            "Inspection Recommended",
            "Unusual sensor pattern detected. Check sensor placement and hive conditions.",
        ),
    }[result["model_prediction"]]
    assert (result["status"], result["recommendation"]) == expected


def test_missing_model_file_is_reported_not_raised(monkeypatch, tmp_path):
    monkeypatch.setenv("IT23136274_COLONY_MODEL_PATH", str(tmp_path / "missing.joblib"))
    service = ColonyHealthModelService()
    service.load_once()
    assert service.available is False
    assert "not found" in service.status["message"]


def test_model_file_is_the_saved_v2_model():
    assert MODEL_PATH.name == "colony_sensor_anomaly_model_v2.joblib"


# ── Routes (simulated Firestore) ───────────────────────────────────

@needs_model
def test_latest_endpoint_returns_structured_prediction(monkeypatch):
    client = make_client(monkeypatch, [_SimulatedDoc(_simulated_reading())])
    response = client.get("/api/v1/colony-health/sensor-anomaly/latest/HIVE_TEST")
    assert response.status_code == 200
    body = response.json()
    assert body["hive_id"] == "HIVE_TEST"
    assert body["temperature"] == 25.0 and body["humidity"] == 60.0
    assert body["timestamp"] == "2026-10-20T12:00:00+00:00"
    assert body["source"] == "firestore_latest"
    assert body["status"] in ("Normal Sensor Pattern", "Inspection Recommended")
    assert body["recommendation"] and body["note"]


@needs_model
def test_latest_endpoint_404_when_hive_has_no_readings(monkeypatch):
    response = make_client(monkeypatch, []).get("/api/v1/colony-health/sensor-anomaly/latest/NOPE")
    assert response.status_code == 404


@needs_model
@pytest.mark.parametrize("overrides", [{"temperature": None}, {"humidity": "wet"}, {"temperature": 99.0}])
def test_latest_endpoint_422_for_invalid_stored_reading(monkeypatch, overrides):
    client = make_client(monkeypatch, [_SimulatedDoc(_simulated_reading(**overrides))])
    response = client.get("/api/v1/colony-health/sensor-anomaly/latest/HIVE_TEST")
    assert response.status_code == 422


def test_endpoints_503_when_model_unavailable(monkeypatch):
    unavailable = ColonyHealthModelService()  # never loaded
    client = make_client(monkeypatch, [_SimulatedDoc(_simulated_reading())], service=unavailable)
    assert client.get("/api/v1/colony-health/sensor-anomaly/latest/HIVE_TEST").status_code == 503
    manual = client.post("/api/v1/colony-health/sensor-anomaly/predict", json={"temperature": 25, "humidity": 60})
    assert manual.status_code == 503
    assert client.get("/api/v1/colony-health/status").json()["model"]["available"] is False


@needs_model
def test_manual_endpoint_validates_and_marks_source(monkeypatch):
    client = make_client(monkeypatch)
    ok = client.post("/api/v1/colony-health/sensor-anomaly/predict", json={"temperature": 25.0, "humidity": 60.0})
    assert ok.status_code == 200
    assert ok.json()["source"] == "manual_input"
    for bad in ({"temperature": "25", "humidity": 60}, {"temperature": 25}, {"temperature": 25, "humidity": 150}):
        assert client.post("/api/v1/colony-health/sensor-anomaly/predict", json=bad).status_code == 422
