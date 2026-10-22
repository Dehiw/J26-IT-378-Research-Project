"""Transparent, preliminary environmental decision support for apiaries."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any
import math


def summarize_history(days):
    """Describe measured history without claiming a seasonal or population trend."""
    valid = lambda value: isinstance(value, (int, float)) and math.isfinite(value)
    temperatures = [d["average_temperature_c"] for d in days if valid(d.get("average_temperature_c"))]
    humidity = [d["average_humidity_percent"] for d in days if valid(d.get("average_humidity_percent"))]
    rainfall = [d["precipitation_mm"] for d in days if valid(d.get("precipitation_mm"))]
    wet_days = sum(value > 0 for value in rainfall)
    return {
        "days_returned": len(days),
        "rainfall_days_available": len(rainfall),
        "total_precipitation_mm": round(sum(rainfall), 2) if rainfall else None,
        "wet_days": wet_days if rainfall else None,
        "mean_temperature_c": round(sum(temperatures) / len(temperatures), 2) if temperatures else None,
        "mean_humidity_percent": round(sum(humidity) / len(humidity), 2) if humidity else None,
        "interpretation": (
            f"Rain was recorded on {wet_days} of {len(rainfall)} days with available rainfall observations. Wet periods may reduce foraging opportunities; compare with direct flight and food-store observations."
            if rainfall else "Insufficient historical rainfall observations."
        ),
        "limitation": "This short observation window is not a seasonal climate trend and cannot estimate flowering, colony growth or population.",
    }


def get_sri_lankan_season(month: int) -> dict[str, str]:
    """Return Sri Lanka's four conventional rainfall seasons by calendar month."""
    if month in (3, 4):
        return {"name": "First Inter-monsoon", "period": "March-April"}
    if month in (5, 6, 7, 8, 9):
        return {"name": "Southwest Monsoon", "period": "May-September"}
    if month in (10, 11):
        return {"name": "Second Inter-monsoon", "period": "October-November"}
    return {"name": "Northeast Monsoon", "period": "December-February"}


def _regional_context(latitude: float | None, longitude: float | None) -> str:
    if latitude is None or longitude is None:
        return "Regional monsoon influence unavailable because location coordinates were not returned."
    if not (5.0 <= latitude <= 10.0 and 79.0 <= longitude <= 82.5):
        return "The selected location appears outside Sri Lanka; Sri Lankan seasonal context may not apply."
    if latitude >= 8.7 or (longitude >= 80.8 and latitude >= 6.5):
        return "Broad north/east location estimate; the Northeast Monsoon can be more influential here."
    if longitude <= 80.1 and latitude <= 8.7:
        return "Broad west/southwest location estimate; the Southwest Monsoon can be more influential here."
    if longitude >= 80.8:
        return "Broad north/east location estimate; the Northeast Monsoon can be more influential here."
    return "Broad central/intermediate location estimate; terrain can alter local rainfall and this simple mapping may not reflect the apiary's exact climate zone."


def analyze_environment(
    *,
    temperature_c: float | None,
    humidity_percent: float | None,
    rainfall_mm: float | None,
    observed_at: str | None,
    latitude: float | None,
    longitude: float | None,
    hive_temperature_c: float | None = None,
    hive_humidity_percent: float | None = None,
    forage_observed: bool | None = None,
    month: int | None = None,
) -> dict[str, Any]:
    """Summarize available outdoor conditions without diagnosing colony health."""
    local_observation = None
    if observed_at:
        try:
            local_observation = datetime.fromisoformat(observed_at.replace(" ", "T"))
        except ValueError:
            local_observation = None
    resolved_month = month or (local_observation.month if local_observation else (datetime.now(timezone.utc) + timedelta(hours=5, minutes=30)).month)
    season = get_sri_lankan_season(resolved_month)
    regional_context = _regional_context(latitude, longitude)

    observations: list[str] = []
    recommendations: list[str] = []
    if temperature_c is None:
        observations.append("Outdoor temperature data is unavailable.")
    else:
        observations.append(
            f"Outdoor temperature was {temperature_c:.1f} °C at the observation time; no locally validated hive-suitability threshold is applied."
        )
    if humidity_percent is None:
        observations.append("Outdoor humidity data is unavailable; it is not a substitute for in-hive humidity.")
    else:
        observations.append(
            f"Outdoor relative humidity was {humidity_percent:.0f}%; in-hive humidity was not inferred from it."
        )

    if rainfall_mm is None:
        bee_assessment = "Insufficient weather data"
        bee_reason = "A current precipitation observation is unavailable, so flight conditions cannot be described."
        observations.append("Rainfall data is unavailable.")
    elif rainfall_mm > 0:
        bee_assessment = "Rain may temporarily interrupt flight"
        bee_reason = (
            f"WeatherAPI recorded {rainfall_mm:.1f} mm precipitation in its current observation. "
            "This snapshot does not establish persistent rainfall or measure bee flight."
        )
        recommendations.append("Observe flight activity and compare it with recent rainfall before drawing conclusions.")
    else:
        bee_assessment = "Flight activity not measured"
        bee_reason = "No precipitation was recorded in this current observation; this does not confirm favorable flight conditions."

    if hive_temperature_c is None or hive_humidity_percent is None:
        colony_growth = {
            "assessment": "Insufficient data",
            "reason": "Hive temperature and humidity readings are not connected; colony growth also requires population or brood observations.",
        }
    else:
        colony_growth = {
            "assessment": "Hive readings available; growth not assessed",
            "reason": "Hive readings are present, but population or brood measurements are needed to assess colony growth.",
        }

    if forage_observed is True:
        food_availability = {
            "assessment": "Forage observed",
            "reason": "A user-reported flowering/forage observation is available; food stores have not been measured.",
        }
    elif forage_observed is False:
        food_availability = {
            "assessment": "Forage not observed",
            "reason": "A user-reported observation says forage was not seen; this does not measure colony food stores.",
        }
    else:
        food_availability = {
            "assessment": "Unknown",
            "reason": "Local flowering observations, forage surveys, and hive food-store measurements are unavailable.",
        }

    recommendations.extend(
        [
            "Review weather trends alongside direct hive observations; this analysis uses outdoor weather only.",
            "Check food stores and local flowering conditions during routine hive inspection.",
            "Investigate unusual hive readings with a qualified beekeeper before taking management action.",
        ]
    )
    return {
        "population": {"assessment": "Not measured", "reason": "Season and weather alone cannot estimate colony population; repeated bee/brood observations are required."},
        "development_suitability": {
            "assessment": "Potential flight constraint" if rainfall_mm is not None and rainfall_mm > 0 else "Inconclusive",
            "reason": "Rain can interrupt foraging. Temperature, humidity and calendar season alone do not establish favorable colony development or available food.",
        },
        "seasonal_outlook": "Season describes regional rainfall timing, not a population forecast. Compare recent rainfall with observed flowering, food stores and brood before judging colony growth.",
        "season": season["name"],
        "season_period": season["period"],
        "regional_context": regional_context,
        "environmental_summary": " ".join(observations),
        "environmental_observations": observations,
        "bee_activity": {"assessment": bee_assessment, "reason": bee_reason},
        "colony_growth": colony_growth,
        "food_availability": food_availability,
        "recommendations": recommendations,
        "data_quality": {
            "weather": "WeatherAPI current outdoor observation",
            "weather_observed_at": observed_at,
            "hive_telemetry": "Unavailable" if hive_temperature_c is None or hive_humidity_percent is None else "Provided readings",
            "forage": "Not measured" if forage_observed is None else "User observation",
            "regional_context": "Broad coordinate-based estimate; not an official climate-zone classification",
            "rules": "Preliminary decision support; thresholds and effects require local validation",
        },
    }
