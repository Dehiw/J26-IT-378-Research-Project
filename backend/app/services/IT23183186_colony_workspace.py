"""Owned observations, management plans and alert review records."""
from datetime import datetime, timezone
from hashlib import sha256
from uuid import uuid4
from fastapi import HTTPException
from fastapi.encoders import jsonable_encoder
from app.services import IT23183186_environment_history as history

DEFAULT_PREFERENCES = {"auto_refresh": True, "refresh_seconds": 300, "in_app_alerts": True}

def _list(ref, kind, user_id, limit=50):
    return [{**d.to_dict(), "id": d.id} for d in ref.collection("IT23183186_" + kind)
        .order_by("saved_at", direction="DESCENDING").limit(limit).stream()
        if (d.to_dict() or {}).get("user_id") == user_id]

def _sensor_history(hive_id):
    from google.api_core.exceptions import FailedPrecondition
    query = history._database().collection("sensor_readings").where("hive_id", "==", hive_id)
    try:
        docs = query.order_by("timestamp", direction="DESCENDING").limit(100).get()
    except FailedPrecondition:
        docs = sorted(query.get(), key=lambda d: str((d.to_dict() or {}).get("timestamp", "")), reverse=True)[:100]
    return jsonable_encoder([{k: (d.to_dict() or {}).get(k) for k in
        ("timestamp", "temperature", "humidity", "weight", "bee_activity")} for d in docs])

def load_workspace(hive_id, user_id):
    ref, _ = history.owned_hive(hive_id, user_id)
    pref = ref.collection("IT23183186_workspace").document("preferences").get()
    preferences = pref.to_dict() or {}
    if preferences.get("user_id") != user_id:
        preferences = DEFAULT_PREFERENCES
    sensor_error = None
    try:
        sensors = _sensor_history(hive_id)
    except Exception:
        sensors = []
        sensor_error = "Sensor history is unavailable. Verify the IoT connection."
    return {"observations": _list(ref, "observations", user_id),
        "care_plans": _list(ref, "care_plans", user_id),
        "alert_reviews": _list(ref, "alert_reviews", user_id, 100),
        "records": [keyed_alerts(r) for r in history.list_snapshots(hive_id, user_id, 100)],
        "preferences": preferences, "sensor_history": sensors, "sensor_error": sensor_error}

def save_item(hive_id, user_id, kind, payload):
    ref, hive = history.owned_hive(hive_id, user_id)
    if kind == "observations" and payload.get("brood_frames") is not None and payload["brood_frames"] > hive.get("num_frames", 100):
        raise HTTPException(422, "Brood frames cannot exceed the hive's frame count.")
    record_id = uuid4().hex
    record = jsonable_encoder({**payload, "id": record_id, "user_id": user_id,
        "hive_id": hive_id, "saved_at": datetime.now(timezone.utc).isoformat()})
    if kind == "care_plans": record["status"] = "planned"
    ref.collection("IT23183186_" + kind).document(record_id).set(record)
    return record

def complete_plan(hive_id, user_id, plan_id):
    ref, _ = history.owned_hive(hive_id, user_id)
    doc = ref.collection("IT23183186_care_plans").document(plan_id)
    plan = doc.get().to_dict() or {}
    if plan.get("user_id") != user_id: raise HTTPException(404, "Care plan not found.")
    plan.update(status="completed", completed_at=datetime.now(timezone.utc).isoformat())
    doc.set(plan)
    return plan

def preferences(hive_id, user_id, payload):
    ref, _ = history.owned_hive(hive_id, user_id)
    record = {**payload, "user_id": user_id, "saved_at": datetime.now(timezone.utc).isoformat()}
    ref.collection("IT23183186_workspace").document("preferences").set(record)
    return record

def review_alert(hive_id, user_id, key):
    ref, _ = history.owned_hive(hive_id, user_id)
    record = {"id": key, "key": key, "user_id": user_id, "saved_at": datetime.now(timezone.utc).isoformat()}
    ref.collection("IT23183186_alert_reviews").document(key).set(record)
    return record

def keyed_alerts(snapshot):
    assessment = snapshot.get("assessment") or {}
    for alert in assessment.get("alerts", []):
        source = alert.get("source")
        time = ((snapshot.get("weather") or {}).get("current") or {}).get("last_updated_epoch") if source == "WeatherAPI" else (snapshot.get("sensor") or {}).get("timestamp")
        if source == "Model A": time = assessment.get("generated_at")
        alert["review_key"] = sha256(f"{alert.get('id')}|{source}|{alert.get('message')}|{time}".encode()).hexdigest()
    return snapshot
