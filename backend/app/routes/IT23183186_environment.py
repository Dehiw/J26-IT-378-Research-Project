import asyncio
import os
from datetime import datetime, timedelta, timezone

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Path, Request
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
    payload = await _weatherapi_get("current.json", {"q": q, "aqi": "yes"})

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
            "cloud_percent": current.get("cloud"),
            "visibility_km": current.get("vis_km"),
            "pressure_mb": current.get("pressure_mb"),
            "dew_point_c": current.get("dewpoint_c"),
            "gust_kph": current.get("gust_kph"),
            "wind_degree": current.get("wind_degree"),
            "air_quality": current.get("air_quality"),
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
                "maximum_wind_kph": summary.get("maxwind_kph"),
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


@router.post("/hives/{hive_id}/records", status_code=201)
async def save_environment_record(
    hive_id: str = Path(..., min_length=1, max_length=128, pattern=r"^[^/]+$"),
    q: str | None = Query(None, min_length=2, max_length=160),
    user_id: str = Depends(get_current_user_id),
):
    """Save a fresh server-generated snapshot, including partial evidence on outages."""
    from app.services import IT23183186_environment_history as history
    try:
        saved_location = await run_in_threadpool(history.hive_location, hive_id, user_id)
        location = q or saved_location
        snapshot = await build_assessment(location, hive_id, user_id)
        record = await run_in_threadpool(history.save_snapshot, hive_id, user_id,
            location, snapshot, "explicit_query" if q else "saved_apiary")
        return {"record": record}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(503, "Could not save the environmental snapshot. Please retry.") from exc


@router.get("/hives/{hive_id}/records")
async def environment_records(
    hive_id: str = Path(..., min_length=1, max_length=128, pattern=r"^[^/]+$"),
    limit: int = Query(20, ge=1, le=100),
    user_id: str = Depends(get_current_user_id),
):
    """Return this owner's latest saved snapshots for a hive."""
    from app.services import IT23183186_environment_history as history
    try:
        records = await run_in_threadpool(history.list_snapshots, hive_id, user_id, limit)
        return {"records": records}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(503, "Saved environmental history is unavailable. Please retry.") from exc


@router.get("/forecast")
async def weather_forecast(q: str = Query(..., min_length=2, max_length=160)):
    """Provider daily/hourly forecasts; actual horizon depends on account access."""
    payload = await _weatherapi_get("forecast.json", {"q": q, "days": "3", "aqi": "yes", "alerts": "no"})
    location = payload.get("location")
    forecast = payload.get("forecast")
    days = forecast.get("forecastday") if isinstance(forecast, dict) else None
    if not isinstance(location, dict) or not isinstance(days, list) or not days:
        raise HTTPException(502, "Weather provider returned an incomplete forecast.")
    return {"location": location, "days": days, "source": "WeatherAPI.com",
            "fetched_at": datetime.now(timezone.utc).isoformat()}


@router.get("/map/tiles/{z}/{x}/{y}.png")
async def map_tile(z: int = Path(..., ge=0, le=18), x: int = Path(..., ge=0), y: int = Path(..., ge=0)):
    from app.services.IT23183186_map_tiles import get_tile
    from fastapi.responses import Response
    if x >= 2 ** z or y >= 2 ** z:
        raise HTTPException(422, "Invalid map tile coordinates.")
    content = await get_tile(z, x, y)
    return Response(content, media_type="image/png", headers={"Cache-Control": "public, max-age=604800"})


from app.schemas.IT23183186_workspace import ColonyObservation, CarePlan, MonitoringPreferences, AlertReview
from app.services import IT23183186_colony_workspace as workspace


async def _workspace_call(function, *args):
    try:
        return await run_in_threadpool(function, *args)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(503, "Colony records are unavailable. Please retry.") from exc


@router.get("/hives/{hive_id}/workspace")
async def colony_workspace(request: Request, hive_id: str = Path(..., min_length=1, max_length=128, pattern=r"^[^/]+$"), user_id: str = Depends(get_current_user_id)):
    result = await _workspace_call(workspace.load_workspace, hive_id, user_id)
    from app.services import IT23183186_environment_history as history
    location = await _workspace_call(history.hive_location, hive_id, user_id)
    result["monitoring"] = workspace.keyed_alerts(await build_assessment(location, hive_id, user_id))
    models = getattr(request.app.state, "image_model_service", None)
    result["models"] = models.status if models else {"model_a": {"available": False}, "model_b": {"available": False}}
    return result


@router.post("/hives/{hive_id}/observations", status_code=201)
async def save_observation(payload: ColonyObservation, hive_id: str = Path(..., min_length=1, max_length=128, pattern=r"^[^/]+$"), user_id: str = Depends(get_current_user_id)):
    return {"record": await _workspace_call(workspace.save_item, hive_id, user_id, "observations", payload.model_dump())}


@router.post("/hives/{hive_id}/care-plans", status_code=201)
async def save_care_plan(payload: CarePlan, hive_id: str = Path(..., min_length=1, max_length=128, pattern=r"^[^/]+$"), user_id: str = Depends(get_current_user_id)):
    return {"record": await _workspace_call(workspace.save_item, hive_id, user_id, "care_plans", payload.model_dump())}


@router.post("/hives/{hive_id}/care-plans/{plan_id}/complete")
async def finish_care_plan(hive_id: str = Path(..., min_length=1, max_length=128, pattern=r"^[^/]+$"), plan_id: str = Path(..., min_length=1, max_length=128, pattern=r"^[^/]+$"), user_id: str = Depends(get_current_user_id)):
    return {"record": await _workspace_call(workspace.complete_plan, hive_id, user_id, plan_id)}


@router.put("/hives/{hive_id}/preferences")
async def save_monitoring_preferences(payload: MonitoringPreferences, hive_id: str = Path(..., min_length=1, max_length=128, pattern=r"^[^/]+$"), user_id: str = Depends(get_current_user_id)):
    return {"preferences": await _workspace_call(workspace.preferences, hive_id, user_id, payload.model_dump())}


@router.post("/hives/{hive_id}/alert-reviews", status_code=201)
async def mark_alert_reviewed(payload: AlertReview, hive_id: str = Path(..., min_length=1, max_length=128, pattern=r"^[^/]+$"), user_id: str = Depends(get_current_user_id)):
    return {"review": await _workspace_call(workspace.review_alert, hive_id, user_id, payload.key)}
