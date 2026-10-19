from fastapi import APIRouter
from pydantic import BaseModel
from datetime import datetime, timezone

from firebase_admin import firestore
from google.api_core.exceptions import FailedPrecondition

from app.firebase.firebase_config import db

router = APIRouter(
    prefix="/sensor-data",
    tags=["Sensor Data"]
)


class SensorData(BaseModel):
    hive_id: str
    temperature: float
    humidity: float
    weight: float


@router.post("")
def save_sensor_data(data: SensorData):

    reading = {
        "hive_id": data.hive_id,
        "temperature": data.temperature,
        "humidity": data.humidity,
        "weight": data.weight,
        "timestamp": datetime.now(timezone.utc)
    }

    doc_ref = db.collection("sensor_readings").document()
    doc_ref.set(reading)

    return {
        "message": "Sensor data saved successfully",
        "document_id": doc_ref.id
    }


@router.get("/latest/{hive_id}")
def get_latest_sensor_data(hive_id: str):
    """Return the most recent sensor reading for a hive, or null if none exist."""
    query = db.collection("sensor_readings").where("hive_id", "==", hive_id)

    try:
        docs = (
            query.order_by("timestamp", direction=firestore.Query.DESCENDING)
            .limit(1)
            .get()
        )
    except FailedPrecondition:
        # Composite index (hive_id ASC, timestamp DESC) not created yet:
        # fall back to sorting in memory so the endpoint still works.
        docs = sorted(
            query.get(),
            key=lambda d: (d.to_dict() or {}).get("timestamp") or datetime.min.replace(tzinfo=timezone.utc),
            reverse=True,
        )[:1]

    if not docs:
        return {"reading": None}

    doc = docs[0]
    data = doc.to_dict() or {}
    timestamp = data.get("timestamp")

    return {
        "reading": {
            "id": doc.id,
            "hive_id": data.get("hive_id"),
            "temperature": data.get("temperature"),
            "humidity": data.get("humidity"),
            "weight": data.get("weight"),
            "timestamp": timestamp.isoformat() if timestamp else None,
        }
    }