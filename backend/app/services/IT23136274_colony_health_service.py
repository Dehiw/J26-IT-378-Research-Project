"""IT23136274 - AI-Based Colony Health Monitoring.

Startup-loaded Isolation Forest V2 sensor anomaly model.

The model (StandardScaler + IsolationForest, trained on MSPB D1 + D2) flags
unusual temperature/humidity patterns. It is an EXPERIMENTAL sensor anomaly
detector, not a validated colony health diagnosis: an exploratory comparison
with beekeeper observations gave only 29.63% agreement.
"""

from __future__ import annotations

import math
import os
from pathlib import Path
from typing import Any

import numpy as np


BACKEND_DIR = Path(__file__).resolve().parents[2]
MODEL_PATH = BACKEND_DIR / "models" / "IT23136274_colony_health" / "colony_sensor_anomaly_model_v2.joblib"
MODEL_NAME = "Isolation Forest V2 (MSPB D1+D2, temperature/humidity)"

# Feature order the model was trained with. Do not reorder.
FEATURE_ORDER = ("temperature", "humidity")

# Valid ranges, identical to the filter used when the model was trained.
TEMPERATURE_RANGE = (-20.0, 60.0)  # °C
HUMIDITY_RANGE = (0.0, 100.0)  # %

PREDICTION_LABELS = {
    1: {
        "status": "Normal Sensor Pattern",
        "recommendation": "No unusual temperature/humidity pattern detected.",
    },
    -1: {
        "status": "Inspection Recommended",
        "recommendation": "Unusual sensor pattern detected. Check sensor placement and hive conditions.",
    },
}

DISCLAIMER = (
    "Experimental sensor anomaly detection only. This prediction does not confirm "
    "colony health and is not a validated diagnosis."
)


class InvalidReadingError(ValueError):
    """A sensor reading cannot be used as model input."""


def _validated_value(name: str, value: Any, valid_range: tuple[float, float]) -> float:
    if value is None:
        raise InvalidReadingError(f"{name} is missing from the sensor reading.")
    # bool is a subclass of int; a True/False reading is not a measurement.
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise InvalidReadingError(f"{name} must be a number.")
    number = float(value)
    if not math.isfinite(number):
        raise InvalidReadingError(f"{name} must be a finite number.")
    low, high = valid_range
    if not low <= number <= high:
        raise InvalidReadingError(f"{name} {number:g} is outside the valid range {low:g} to {high:g}.")
    return number


def validate_reading(temperature: Any, humidity: Any) -> tuple[float, float]:
    """Return (temperature, humidity) as floats, or raise InvalidReadingError."""
    return (
        _validated_value("temperature", temperature, TEMPERATURE_RANGE),
        _validated_value("humidity", humidity, HUMIDITY_RANGE),
    )


class ColonyHealthModelService:
    def __init__(self) -> None:
        self.model: Any = None
        self._load_attempted = False
        self.status: dict[str, str | bool] = {
            "available": False,
            "message": "The colony sensor anomaly model has not been loaded.",
        }

    @property
    def available(self) -> bool:
        return bool(self.status["available"])

    def load_once(self) -> None:
        """Load the saved model once per application process. Never writes the file."""
        if self._load_attempted:
            return
        self._load_attempted = True
        path = Path(os.getenv("IT23136274_COLONY_MODEL_PATH", str(MODEL_PATH)))
        if not path.is_file():
            self.status = {"available": False, "message": f"Model file not found: {path.name}"}
            return
        try:
            import joblib

            model = joblib.load(path)
            if getattr(model, "n_features_in_", None) != len(FEATURE_ORDER):
                raise ValueError("Model does not expect exactly two input features.")
            self.model = model
            self.status = {"available": True, "message": f"{MODEL_NAME} loaded."}
        except Exception as exc:
            self.status = {
                "available": False,
                "message": f"Model could not be loaded: {type(exc).__name__}: {exc}",
            }

    def predict(self, temperature: float, humidity: float) -> dict:
        """Run the model on one validated reading. Returns labels only, no scores."""
        if not self.available:
            raise RuntimeError(str(self.status["message"]))
        features = np.array([[temperature, humidity]], dtype=float)
        prediction = int(self.model.predict(features)[0])
        if prediction not in PREDICTION_LABELS:
            raise RuntimeError(f"Unexpected model output: {prediction}")
        return {
            "model_prediction": prediction,
            **PREDICTION_LABELS[prediction],
            "model": MODEL_NAME,
            "note": DISCLAIMER,
        }
