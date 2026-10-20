import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from firebase_admin import firestore
from google.api_core.exceptions import FailedPrecondition
from google.cloud.firestore_v1.base_query import FieldFilter

from app.firebase.firebase_config import db

logger = logging.getLogger("uvicorn.error")

router = APIRouter(
    prefix="/sensor-data",
    tags=["Sensor Data"]
)

# Seconds between SSE keep-alive comments while no new readings arrive.
HEARTBEAT_SECONDS = 15


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


# ── Queries ────────────────────────────────────────────────────────
# Both queries need the composite index:
#   sensor_readings: hive_id ASC, timestamp DESC

def _latest_query(hive_id: str):
    return (
        db.collection("sensor_readings")
        .where(filter=FieldFilter("hive_id", "==", hive_id))
        .order_by("timestamp", direction=firestore.Query.DESCENDING)
        .limit(1)
    )


def _range_query(hive_id: str, start: datetime, end: Optional[datetime]):
    query = (
        db.collection("sensor_readings")
        .where(filter=FieldFilter("hive_id", "==", hive_id))
        .where(filter=FieldFilter("timestamp", ">=", start))
    )
    if end is not None:
        query = query.where(filter=FieldFilter("timestamp", "<=", end))
    return query.order_by("timestamp", direction=firestore.Query.DESCENDING)


def _as_utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def _serialize(doc) -> dict:
    data = doc.to_dict() or {}
    timestamp = data.get("timestamp")
    return {
        "id": doc.id,
        "hive_id": data.get("hive_id"),
        "temperature": data.get("temperature"),
        "humidity": data.get("humidity"),
        "weight": data.get("weight"),
        "timestamp": timestamp.isoformat() if timestamp else None,
    }


def _run_query(query):
    """Run a one-time query, logging the real Firestore exception on failure."""
    try:
        return query.get()
    except FailedPrecondition as e:
        logger.exception("sensor_readings query failed (missing composite index)")
        raise HTTPException(
            status_code=500,
            detail=f"Missing Firestore index for sensor_readings: {e.message}",
        )
    except Exception as e:
        logger.exception("sensor_readings query failed")
        raise HTTPException(
            status_code=500,
            detail=f"Firestore query failed: {type(e).__name__}: {e}",
        )


def _sse_response(query, build_event) -> StreamingResponse:
    """Stream a Firestore snapshot listener to the client as Server-Sent Events.

    build_event(docs, changes, is_first) returns the JSON payload for each snapshot.
    """
    # Fail fast (with the index link) instead of opening a listener that never fires.
    _run_query(query.limit(1))

    async def events():
        loop = asyncio.get_running_loop()
        queue: asyncio.Queue = asyncio.Queue()
        state = {"first": True}

        def on_snapshot(docs, changes, read_time):
            try:
                payload = build_event(docs, changes, state["first"])
            except Exception:
                logger.exception("sensor_readings snapshot handling failed")
                return
            state["first"] = False
            loop.call_soon_threadsafe(queue.put_nowait, payload)

        watch = query.on_snapshot(on_snapshot)
        try:
            while True:
                try:
                    payload = await asyncio.wait_for(queue.get(), timeout=HEARTBEAT_SECONDS)
                    yield f"data: {json.dumps(payload)}\n\n"
                except asyncio.TimeoutError:
                    if not watch.is_active:
                        # Listener died (e.g. network loss); end so the client reconnects.
                        logger.warning("sensor_readings snapshot listener stopped; closing stream")
                        break
                    yield ": keep-alive\n\n"
        finally:
            watch.unsubscribe()

    return StreamingResponse(
        events(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


# ── Read Endpoints ─────────────────────────────────────────────────

@router.get("/latest/{hive_id}")
def get_latest_sensor_data(hive_id: str):
    """Return the most recent sensor reading for a hive, or null if none exist."""
    docs = _run_query(_latest_query(hive_id))
    return {"reading": _serialize(docs[0]) if docs else None}


@router.get("/stream/latest/{hive_id}")
def stream_latest_sensor_data(hive_id: str):
    """Live stream of the latest reading. Each event: {"reading": {...} | null}."""

    def build_event(docs, changes, is_first):
        return {"reading": _serialize(docs[0]) if docs else None}

    return _sse_response(_latest_query(hive_id), build_event)


@router.get("/stream/history/{hive_id}")
def stream_sensor_history(
    hive_id: str,
    start: datetime,
    end: Optional[datetime] = None,
):
    """Live stream of readings with start <= timestamp (<= end).

    First event: {"type": "reset", "readings": [...]} with every matching reading.
    Later events: {"type": "changes", "readings": [...added/modified], "removed": [ids]}.
    """

    def build_event(docs, changes, is_first):
        if is_first:
            return {"type": "reset", "readings": [_serialize(d) for d in docs], "removed": []}
        upserts, removed = [], []
        for change in changes:
            if change.type.name == "REMOVED":
                removed.append(change.document.id)
            else:
                upserts.append(_serialize(change.document))
        return {"type": "changes", "readings": upserts, "removed": removed}

    query = _range_query(hive_id, _as_utc(start), _as_utc(end) if end else None)
    return _sse_response(query, build_event)
