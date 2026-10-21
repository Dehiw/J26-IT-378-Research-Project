import asyncio
import os
from datetime import datetime, timedelta, timezone

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query
from starlette.concurrency import run_in_threadpool
from app.core.security import get_current_user_id
from app.services.IT23183186_colony_assessment import assess_colony

from app.services.IT23183186_environmental_impact import analyze_environment, summarize_history

router = APIRouter(prefix="/environment", tags=["Environment"])


async def _weatherapi_get(endpoint: str, params: dict[str, str]):
    api_key = os.getenv("WEATHERAPI_KEY", "").strip()
    if not api_key:
        raise HTTPException(
            status_code=503,
            detail="WeatherAPI is not configured. Set WEATHERAPI_KEY in backend/.env.",
        )

    try:
        async with httpx.AsyncClient(timeout=12.0) as client:
            response = await client.get(
                f"https://api.weatherapi.com/v1/{endpoint}",
                params={"key": api_key, **params},
            )
    except httpx.TimeoutException as exc:
        raise HTTPException(status_code=504, detail="Weather provider timed out.") from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail="Could not reach WeatherAPI.") from exc

    try:
        payload = response.json()
        if not isinstance(payload, dict):
            raise ValueError("Expected provider object")
    except ValueError as exc:
        raise HTTPException(status_code=502, detail="Weather provider returned an invalid response.") from exc
    if response.is_error:
        code = payload.get("error", {}).get("code")
        if code in (1002, 2006, 2008):
            raise HTTPException(status_code=503, detail="Weather service credentials need updating. Update the backend WeatherAPI key and restart the backend.")
        if code in (2007, 2009):
            raise HTTPException(status_code=503, detail="Weather provider access is unavailable for this request. Check the account quota and history subscription.")
        provider_error = payload.get("error", {}).get("message", "Weather lookup failed.")
        raise HTTPException(status_code=response.status_code, detail=provider_error)
    return payload


@router.get("/weather")
async def current_weather(q: str = Query(..., min_length=2, max_length=160)):
    """Return current outdoor conditions for an apiary location."""
    payload = await _weatherapi_get("current.json", {"q": q, "aqi": "no"})

    location = payload.get("location")
    current = payload.get("current")
    if not isinstance(location, dict) or not isinstance(current, dict):
        raise HTTPException(status_code=502, detail="Weather provider returned incomplete current conditions.")
    condition = current.get("condition", {})
    return {
        "location": {
            "name": location.get("name"),
            "region": location.get("region"),
            "country": location.get("country"),
            "localtime": location.get("localtime"),
            "latitude": location.get("lat"),
            "longitude": location.get("lon"),
        },
        "current": {
            "temperature_c": current.get("temp_c"),
            "humidity_percent": current.get("humidity"),
            "feels_like_c": current.get("feelslike_c"),
            "wind_kph": current.get("wind_kph"),
            "wind_direction": current.get("wind_dir"),
            "precipitation_mm": current.get("precip_mm"),
            "uv_index": current.get("uv"),
            "condition": condition.get("text"),
            "icon": condition.get("icon"),
            "last_updated": current.get("last_updated"),
            "last_updated_epoch": current.get("last_updated_epoch"),
        },
        "source": "WeatherAPI.com",
    }


@router.get("/impact")
async def environmental_impact(q: str = Query(..., min_length=2, max_length=160)):
    """Analyze current outdoor weather using transparent preliminary rules."""
    weather = await current_weather(q)
    location = weather["location"]
    current = weather["current"]
    analysis = analyze_environment(
        temperature_c=current.get("temperature_c"),
        humidity_percent=current.get("humidity_percent"),
        rainfall_mm=current.get("precipitation_mm"),
        observed_at=current.get("last_updated"),
        latitude=location.get("latitude"),
        longitude=location.get("longitude"),
    )
    return {"weather": weather, "analysis": analysis}


@router.get("/weather/history")
async def weather_history(
    q: str = Query(..., min_length=2, max_length=160),
    days: int = Query(7, ge=1, le=7),
):
    """Return daily outdoor weather summaries for the previous 1-7 days."""
    today = (datetime.now(timezone.utc) + timedelta(hours=5, minutes=30)).date()
    dates = [today - timedelta(days=offset) for offset in range(days, 0, -1)]

    # WeatherAPI's history endpoint accepts one date per request. Keep this
    # request count bounded to seven days and return a clear provider error if
    # the configured subscription does not include historical data.
    results = await asyncio.gather(
        *(
            _weatherapi_get("history.json", {"q": q, "dt": day.isoformat()})
            for day in dates
        ),
        return_exceptions=True,
    )
    failures = [result for result in results if isinstance(result, Exception)]
    if failures:
        first = failures[0]
        if isinstance(first, HTTPException):
            raise first
        raise HTTPException(status_code=502, detail="Could not load historical weather.")

    history = []
    for day, payload in zip(dates, results):
        forecast_days = payload.get("forecast", {}).get("forecastday", [])
        if not forecast_days:
            continue
        summary = forecast_days[0].get("day", {})
        history.append(
            {
                "date": day.isoformat(),
                "average_temperature_c": summary.get("avgtemp_c"),
                "min_temperature_c": summary.get("mintemp_c"),
                "max_temperature_c": summary.get("maxtemp_c"),
                "average_humidity_percent": summary.get("avghumidity"),
                "precipitation_mm": summary.get("totalprecip_mm"),
            }
        )

    first_payload = results[0]
    location = first_payload.get("location", {})
    return {
        "location": {
            "name": location.get("name"),
            "region": location.get("region"),
            "country": location.get("country"),
        },
        "days": history,
        "analysis": summarize_history(history),
        "source": "WeatherAPI.com",
    }


def _owned_hive_sensor(hive_id: str, user_id: str):
    from app.firebase.firebase_config import db
    from app.routes.sensor_data import get_latest_sensor_data
    hive = db.collection("hives").document(hive_id).get()
    if not hive.exists or (hive.to_dict() or {}).get("user_id") != user_id:
        raise HTTPException(status_code=404, detail="Hive not found.")
    try:
        return get_latest_sensor_data(hive_id).get("reading")
    except Exception:
        return None


async def build_assessment(q, hive_id, user_id, model_a=None, model_b=None):
    # Read only owned telemetry; provider outages leave other evidence usable.
    sensor = await run_in_threadpool(_owned_hive_sensor, hive_id, user_id) if hive_id else None
    weather = None
    weather_error = None
    if q:
        try:
            weather = await current_weather(q)
        except HTTPException:
            weather_error = "Outdoor weather is unavailable. Retry the weather lookup."
    assessment = assess_colony(weather=weather, sensor=sensor, model_a=model_a, model_b=model_b)
    analysis = None
    if weather:
        current, location = weather["current"], weather["location"]
        analysis = analyze_environment(
            temperature_c=current.get("temperature_c"), humidity_percent=current.get("humidity_percent"),
            rainfall_mm=current.get("precipitation_mm"), observed_at=current.get("last_updated"),
            latitude=location.get("latitude"), longitude=location.get("longitude"),
            hive_temperature_c=(sensor or {}).get("temperature") if assessment["evidence"]["sensors"] == "fresh" else None,
            hive_humidity_percent=(sensor or {}).get("humidity") if assessment["evidence"]["sensors"] == "fresh" else None,
        )
    return {"assessment": assessment, "weather": weather, "environment": analysis, "sensor": sensor, "weather_error": weather_error}


@router.get("/assessment")
async def colony_assessment(
    q: str | None = Query(None, min_length=2, max_length=160),
    hive_id: str | None = Query(None, min_length=1, max_length=128),
    user_id: str = Depends(get_current_user_id),
):
    """Current, authenticated monitoring snapshot; alerts are not persisted or pushed."""
    return await build_assessment(q, hive_id, user_id)
