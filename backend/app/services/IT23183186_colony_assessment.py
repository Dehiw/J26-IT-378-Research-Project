"""Evidence-based, unvalidated monitoring rules; never a disease probability."""

from datetime import datetime, timezone
import math


RULES = {
    "outdoor_temperature_watch_c": [15, 35],
    "outdoor_temperature_high_c": [10, 40],
    "outdoor_humidity_watch_percent": 85,
    "rain_watch_mm": 0,
    "hive_temperature_watch_c": [30, 38],
    "hive_humidity_watch_percent": [40, 85],
    "maximum_sensor_age_minutes": 60,
    "maximum_weather_age_minutes": 120,
}


def fresh_timestamp(value, minutes, now):
    try:
        stamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if stamp.tzinfo is None:
            return False
        return -300 <= (now - stamp).total_seconds() <= minutes * 60
    except (TypeError, ValueError, AttributeError):
        return False


def number(value):
    return isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value)


def assess_colony(*, weather=None, sensor=None, model_a=None, model_b=None, now=None):
    now = now or datetime.now(timezone.utc)
    alerts = []
    missing = []

    def alert(key, severity, source, message):
        alerts.append({"id": key, "severity": severity, "source": source, "message": message})

    current = (weather or {}).get("current", {})
    epoch = current.get("last_updated_epoch")
    try:
        weather_stamp = datetime.fromtimestamp(epoch, timezone.utc).isoformat() if number(epoch) else None
    except (ValueError, OverflowError, OSError):
        weather_stamp = None
    weather_fresh = fresh_timestamp(weather_stamp, RULES["maximum_weather_age_minutes"], now)
    if not weather_fresh:
        missing.append("Fresh outdoor weather (within 120 minutes)")
    else:
        temp = current.get("temperature_c")
        humidity = current.get("humidity_percent")
        rain = current.get("precipitation_mm")
        for name, value in (("temperature", temp), ("humidity", humidity), ("precipitation", rain)):
            if not number(value):
                missing.append(f"Outdoor {name}")
        low, high = RULES["outdoor_temperature_watch_c"]
        extreme_low, extreme_high = RULES["outdoor_temperature_high_c"]
        if number(temp) and (temp <= low or temp >= high):
            severity = "high" if temp <= extreme_low or temp >= extreme_high else "warning"
            alert("outdoor_temperature", severity, "WeatherAPI", f"Outdoor temperature {temp:g} C crosses the preliminary monitoring band. Check local flight activity and hive conditions.")
        if number(humidity) and humidity >= RULES["outdoor_humidity_watch_percent"]:
            alert("outdoor_humidity", "warning", "WeatherAPI", f"Outdoor humidity is {humidity:g}%. Inspect ventilation and moisture; hive humidity has not been inferred.")
        if number(rain) and rain > RULES["rain_watch_mm"]:
            alert("rain", "warning", "WeatherAPI", f"Current precipitation is {rain:g} mm. Rain may interrupt foraging; this is not a daily rainfall total.")

    sensor_fresh = fresh_timestamp((sensor or {}).get("timestamp"), RULES["maximum_sensor_age_minutes"], now)
    if not sensor_fresh:
        missing.append("Fresh hive sensor readings (within 60 minutes)")
    else:
        for field, (low, high), unit in (("temperature", RULES["hive_temperature_watch_c"], "C"), ("humidity", RULES["hive_humidity_watch_percent"], "%")):
            value = sensor.get(field)
            if not number(value):
                missing.append(f"Hive {field}")
            elif value < low or value > high:
                alert(f"hive_{field}", "warning", "Hive sensor", f"Hive {field} {value:g}{unit} is outside the preliminary {low}-{high}{unit} monitoring band. Verify sensor placement and inspect the hive.")

    a_available = bool(model_a and model_a.get("status", "complete") == "complete" and model_a.get("predicted_class") in ("healthy", "varroa_positive"))
    positive = a_available and model_a["predicted_class"] == "varroa_positive"
    if not a_available:
        missing.append("Supported individual-bee image inference")
    if positive:
        alert("varroa_indicator", "warning", "Model A", "A compatible bee image was classified Varroa-positive. Arrange direct inspection or an appropriate mite assessment; this is not a confirmed diagnosis.")
    environmental = [a for a in alerts if a["source"] != "Model A"]
    return {
        "generated_at": now.isoformat(),
        "status": "preliminary" if positive or environmental else "inconclusive",
        "disease_risk": "elevated_indicator" if positive else "inconclusive",
        "environmental_risk": "high" if any(a["severity"] == "high" for a in environmental) else "watch" if environmental else "no_rule_triggered" if weather_fresh else "unavailable",
        "summary": "A visual Varroa indicator requires follow-up." if positive else "Available evidence does not establish colony disease risk.",
        "alerts": alerts,
        "missing_inputs": missing,
        "evidence": {
            "weather": "fresh" if weather_fresh else "missing_or_stale",
            "sensors": "fresh" if sensor_fresh else "missing_or_stale",
            "model_a": "available" if a_available else "unavailable",
            "model_b": "structural_only" if model_b and model_b.get("status", "complete") == "complete" else "unavailable",
        },
        "rules_version": "IT23183186-monitoring-v1",
        "rules": RULES,
        "limitations": [
            "Monitoring bands are configurable research defaults, not validated biological or disease thresholds; species and sensor placement matter.",
            "No numeric disease probability is calculated. Weather does not diagnose disease, and model confidence is not disease probability.",
            "Model B describes comb/frame structures and does not identify AFB, EFB, Chalkbrood or Sacbrood.",
            "No alert does not establish favorable colony growth, adequate food or a healthy population.",
        ],
    }
