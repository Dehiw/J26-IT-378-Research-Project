import asyncio
from unittest.mock import AsyncMock

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from app.routes import IT23183186_environment as routes
from app.services import IT23183186_map_tiles as tiles


def client():
    app = FastAPI()
    app.include_router(routes.router)
    return TestClient(app)


def test_forecast_forwards_location_and_preserves_real_days(monkeypatch):
    payload = {"location": {"lat": 7.29, "lon": 80.63, "localtime": "2026-10-21 15:00"},
        "forecast": {"forecastday": [{"date": "2026-10-21", "day": {"maxtemp_c": 30},
            "hour": [{"time": "2026-10-21 16:00", "temp_c": 28}]}]}}
    get = AsyncMock(return_value=payload)
    monkeypatch.setattr(routes, "_weatherapi_get", get)
    response = client().get("/environment/forecast?q=7.29,80.63")
    assert response.status_code == 200
    assert response.json()["days"] == payload["forecast"]["forecastday"]
    assert len(response.json()["days"]) == 1  # no invented days to fill the requested horizon
    get.assert_awaited_once_with("forecast.json", {"q": "7.29,80.63", "days": "3", "aqi": "yes", "alerts": "no"})


def test_incomplete_forecast_is_an_error(monkeypatch):
    monkeypatch.setattr(routes, "_weatherapi_get", AsyncMock(return_value={"location": {}, "forecast": {"forecastday": []}}))
    assert client().get("/environment/forecast?q=Kandy").status_code == 502


def test_optional_current_metrics_are_forwarded_without_fake_defaults(monkeypatch):
    current = {"temp_c": 28, "humidity": 70, "cloud": 80, "pressure_mb": 1010, "vis_km": 10,
        "gust_kph": 14, "wind_degree": 245, "air_quality": {"us-epa-index": 2}}
    monkeypatch.setattr(routes, "_weatherapi_get", AsyncMock(return_value={"location": {"lat": 7.29, "lon": 80.63}, "current": current}))
    body = client().get("/environment/weather?q=Kandy").json()
    assert body["location"]["latitude"] == 7.29
    assert body["current"]["cloud_percent"] == 80
    assert body["current"]["visibility_km"] == 10
    assert body["current"]["air_quality"] == {"us-epa-index": 2}
    assert body["current"]["dew_point_c"] is None


@pytest.mark.parametrize("path", ["19/0/0", "2/4/0", "2/0/4", "2/-1/0"])
def test_bad_tile_coordinates_are_rejected(path):
    assert client().get(f"/environment/map/tiles/{path}.png").status_code == 422


def test_tile_cache_prevents_repeat_downloads(tmp_path, monkeypatch):
    monkeypatch.setattr(tiles, "CACHE_DIR", tmp_path)
    content = b"\x89PNG\r\n\x1a\nfixture"
    requests = []
    class Client:
        def __init__(self, **kwargs): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *args): pass
        async def get(self, url, headers):
            requests.append((url, headers))
            return httpx.Response(200, content=content)
    monkeypatch.setattr(tiles.httpx, "AsyncClient", Client)
    assert asyncio.run(tiles.get_tile(8, 185, 122)) == content
    assert asyncio.run(tiles.get_tile(8, 185, 122)) == content
    assert len(requests) == 1
    assert requests[0][1]["User-Agent"] == "HiveSenseResearch/1.0"
    assert (tmp_path / "8" / "185" / "122.png").read_bytes() == content


def test_map_response_is_cacheable(monkeypatch):
    monkeypatch.setattr(tiles, "get_tile", AsyncMock(return_value=b"png"))
    response = client().get("/environment/map/tiles/8/185/122.png")
    assert response.status_code == 200
    assert response.headers["content-type"] == "image/png"
    assert response.headers["cache-control"] == "public, max-age=604800"
