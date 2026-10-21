"""IT23136274 - Colony health sensor anomaly endpoints.

Mounted under /api/v1/colony-health by app/main.py. Like /sensor-data, these
routes do not require a login (local development; production access control
is reviewed separately).
"""

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from app.routes.sensor_data import _latest_query, _run_query, _serialize
from app.services.IT23136274_colony_health_service import (
    ColonyHealthModelService,
    InvalidReadingError,
    validate_reading,
)

router = APIRouter(prefix="/colony-health", tags=["Colony Health (IT23136274)"])


class ManualSensorInput(BaseModel):
    # strict: numeric strings such as "28.3" are rejected instead of coerced.
    temperature: float = Field(..., strict=True, description="Hive temperature in °C", examples=[28.3])
    humidity: float = Field(..., strict=True, description="Hive relative humidity in %", examples=[84.3])


def _service(request: Request) -> ColonyHealthModelService:
    return request.app.state.colony_health_model_service


def _predict(service: ColonyHealthModelService, temperature, humidity) -> dict:
    if not service.available:
        raise HTTPException(status_code=503, detail=service.status["message"])
    try:
        temperature, humidity = validate_reading(temperature, humidity)
    except InvalidReadingError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    try:
        return {"temperature": temperature, "humidity": humidity, **service.predict(temperature, humidity)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Sensor anomaly prediction failed.") from exc


@router.get("/status")
def model_status(request: Request):
    """Whether the Isolation Forest V2 model loaded at startup."""
    return {"model": _service(request).status}


@router.get("/sensor-anomaly/latest/{hive_id}")
def predict_latest_reading(hive_id: str, request: Request):
    """Run the anomaly model on the most recent Firestore reading for a hive."""
    service = _service(request)
    if not service.available:
        raise HTTPException(status_code=503, detail=service.status["message"])
    docs = _run_query(_latest_query(hive_id))
    if not docs:
        raise HTTPException(status_code=404, detail=f"No sensor readings found for hive '{hive_id}'.")
    reading = _serialize(docs[0])
    result = _predict(service, reading["temperature"], reading["humidity"])
    return {
        "hive_id": reading["hive_id"],
        "reading_id": reading["id"],
        "timestamp": reading["timestamp"],
        "source": "firestore_latest",
        **result,
    }


@router.post("/sensor-anomaly/predict")
def predict_manual_input(data: ManualSensorInput, request: Request):
    """Run the anomaly model on manually entered values (testing only; nothing is read or saved)."""
    return {
        "hive_id": None,
        "reading_id": None,
        "timestamp": None,
        "source": "manual_input",
        **_predict(_service(request), data.temperature, data.humidity),
    }
