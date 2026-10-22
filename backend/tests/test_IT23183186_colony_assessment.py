from datetime import datetime, timedelta, timezone
import asyncio
import httpx
import pytest

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.core.security import get_current_user_id
from app.routes import IT23183186_environment as routes
from app.services.IT23183186_colony_assessment import assess_colony
from app.services.IT23183186_environmental_impact import analyze_environment, summarize_history


NOW = datetime(2026, 10, 20, 10, tzinfo=timezone.utc)


def weather(temp=28, humidity=65, rain=0, age=0):
    return {"current": {"temperature_c": temp, "humidity_percent": humidity,
                        "precipitation_mm": rain, "last_updated_epoch": (NOW - timedelta(minutes=age)).timestamp()}}


def test_no_evidence_never_becomes_low_risk():
    result = assess_colony(now=NOW)
    assert result["status"] == result["disease_risk"] == "inconclusive"
    assert result["environmental_risk"] == "unavailable"
    assert not result["alerts"]


def test_stale_weather_and_sensor_do_not_trigger_alerts():
    result = assess_colony(weather=weather(temp=45, age=121),
        sensor={"temperature": 45, "humidity": 95, "timestamp": (NOW - timedelta(minutes=61)).isoformat()}, now=NOW)
    assert not result["alerts"]
    assert result["evidence"]["sensors"] == "missing_or_stale"


def test_high_weather_and_abnormal_fresh_sensor_are_separate_from_disease():
    result = assess_colony(weather=weather(temp=40, humidity=85, rain=1),
        sensor={"temperature": 39, "humidity": 90, "timestamp": NOW.isoformat()}, now=NOW)
    assert result["environmental_risk"] == "high"
    assert result["disease_risk"] == "inconclusive"
    assert {a["id"] for a in result["alerts"]} == {"outdoor_temperature", "outdoor_humidity", "rain", "hive_temperature", "hive_humidity"}


def test_structural_detections_and_healthy_crop_do_not_confirm_colony_health():
    result = assess_colony(weather=weather(), model_a={"predicted_class": "healthy"},
        model_b={"detections": [{"class_name": "CappedWorkerBroodCell"}]}, now=NOW)
    assert result["disease_risk"] == "inconclusive"
    assert result["evidence"]["model_b"] == "structural_only"


def test_varroa_indicator_does_not_produce_probability():
    result = assess_colony(model_a={"status": "complete", "predicted_class": "varroa_positive", "class_scores": {"varroa_positive": .99}}, now=NOW)
    assert result["disease_risk"] == "elevated_indicator"
    assert [a["id"] for a in result["alerts"]] == ["varroa_indicator"]
    assert "score" not in result


def client(authenticated=True):
    app = FastAPI()
    app.include_router(routes.router, prefix="/api/v1")
    if authenticated:
        app.dependency_overrides[get_current_user_id] = lambda: "owner"
    return TestClient(app)


def test_assessment_requires_authentication():
    assert client(False).get("/api/v1/environment/assessment").status_code == 401


def test_foreign_hive_is_rejected(monkeypatch):
    def reject(hive_id, user_id):
        assert user_id == "owner"
        raise HTTPException(404, "Hive not found.")
    monkeypatch.setattr(routes, "_owned_hive_sensor", reject)
    assert client().get("/api/v1/environment/assessment?hive_id=foreign").status_code == 404


def test_provider_outage_returns_partial_evidence(monkeypatch):
    async def unavailable(q):
        raise HTTPException(503, "Provider unavailable")
    monkeypatch.setattr(routes, "current_weather", unavailable)
    response = client().get("/api/v1/environment/assessment?q=Colombo")
    assert response.status_code == 200
    assert response.json()["weather_error"]
    assert response.json()["assessment"]["disease_risk"] == "inconclusive"


def test_season_does_not_invent_population():
    result = analyze_environment(temperature_c=28, humidity_percent=65, rainfall_mm=0,
        observed_at="2026-10-20 12:00", latitude=6.9, longitude=79.8)
    assert result["season"] == "Second Inter-monsoon"
    assert result["population"]["assessment"] == "Not measured"
    assert result["development_suitability"]["assessment"] == "Inconclusive"


def test_history_counts_missing_rain_separately_from_dry_days():
    result = summarize_history([
        {"precipitation_mm": 2, "average_temperature_c": 28},
        {"precipitation_mm": 0, "average_temperature_c": 30},
        {"precipitation_mm": None},
    ])
    assert result["total_precipitation_mm"] == 2
    assert result["rainfall_days_available"] == 2
    assert result["wet_days"] == 1
    assert result["mean_temperature_c"] == 29


def test_invalid_weather_key_is_configuration_failure_not_user_auth(monkeypatch):
    original_client = httpx.AsyncClient
    transport = httpx.MockTransport(lambda request: httpx.Response(401, json={"error": {"code": 2006, "message": "API key is invalid."}}))
    monkeypatch.setenv("WEATHERAPI_KEY", "test-only-not-a-real-key")
    monkeypatch.setattr(routes.httpx, "AsyncClient", lambda **kwargs: original_client(transport=transport, **kwargs))
    with pytest.raises(HTTPException) as error:
        asyncio.run(routes._weatherapi_get("current.json", {"q": "Colombo"}))
    assert error.value.status_code == 503
    assert "credentials need updating" in error.value.detail
    assert "test-only-not-a-real-key" not in error.value.detail
