"""Owned Firestore history for server-generated environmental snapshots."""
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import HTTPException
from fastapi.encoders import jsonable_encoder

COLLECTION = "IT23183186_environment_history"


def _database():
    from app.firebase.firebase_config import db
    return db


def owned_hive(hive_id, user_id):
    ref = _database().collection("hives").document(hive_id)
    hive = ref.get()
    data = hive.to_dict() or {}
    if not hive.exists or data.get("user_id") != user_id:
        raise HTTPException(status_code=404, detail="Hive not found.")
    return ref, data


def hive_location(hive_id, user_id):
    _, hive = owned_hive(hive_id, user_id)
    apiary_id = hive.get("apiary_id")
    if not apiary_id:
        raise HTTPException(422, "This hive has no saved apiary location.")
    apiary = _database().collection("apiaries").document(apiary_id).get()
    data = apiary.to_dict() or {}
    if not apiary.exists or data.get("user_id") != user_id:
        raise HTTPException(404, "Apiary not found.")
    gps = (data.get("gps_location") or "").strip()
    name = (data.get("location_name") or "").strip()
    if not gps and not name:
        raise HTTPException(422, "Set an apiary location before saving environmental readings.")
    return gps or f"{name}, Sri Lanka"


def save_snapshot(hive_id, user_id, location, snapshot, location_source):
    ref, hive = owned_hive(hive_id, user_id)
    record_id = uuid4().hex
    record = jsonable_encoder({
        "id": record_id, "user_id": user_id, "hive_id": hive_id,
        "hive_name": hive.get("name"), "apiary_id": hive.get("apiary_id"),
        "saved_at": datetime.now(timezone.utc).isoformat(),
        "location_query": location, "location_source": location_source,
        "schema_version": 1, **snapshot,
    })
    ref.collection(COLLECTION).document(record_id).set(record)
    return record


def list_snapshots(hive_id, user_id, limit):
    ref, _ = owned_hive(hive_id, user_id)
    docs = ref.collection(COLLECTION).order_by("saved_at", direction="DESCENDING").limit(limit).stream()
    # Ownership is also checked per record to prevent exposure after hive transfer.
    return [{**doc.to_dict(), "id": doc.id} for doc in docs
            if (doc.to_dict() or {}).get("user_id") == user_id]
