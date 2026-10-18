import os

import httpx
from fastapi import APIRouter, HTTPException, Query

router = APIRouter(prefix="/environment", tags=["Environment"])


@router.get("/weather")
async def current_weather(q: str = Query(..., min_length=2, max_length=160)):
    """Return current outdoor conditions for an apiary location."""
    api_key = os.getenv("WEATHERAPI_KEY")
    if not api_key:
        raise HTTPException(
            status_code=503,
            detail="WeatherAPI is not configured. Set WEATHERAPI_KEY in backend/.env.",
        )

    try:
        async with httpx.AsyncClient(timeout=12.0) as client:
            response = await client.get(
                "https://api.weatherapi.com/v1/current.json",
                params={"key": api_key, "q": q, "aqi": "no"},
            )
    except httpx.TimeoutException as exc:
        raise HTTPException(status_code=504, detail="Weather provider timed out.") from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail="Could not reach WeatherAPI.") from exc

    payload = response.json()
    if response.is_error:
        provider_error = payload.get("error", {}).get("message", "Weather lookup failed.")
        raise HTTPException(status_code=response.status_code, detail=provider_error)

    location = payload["location"]
    current = payload["current"]
    condition = current.get("condition", {})
    return {
        "location": {
            "name": location.get("name"),
            "region": location.get("region"),
            "country": location.get("country"),
            "localtime": location.get("localtime"),
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
        },
        "source": "WeatherAPI.com",
    }
