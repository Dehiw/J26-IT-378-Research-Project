"""Acoustic (queen status) endpoints, mounted under /api/v1/acoustic by app/acoustic_main.py."""

import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile

from app.firebase.firebase_config import db
from app.routes.auth import get_current_user_id
from app.services import acoustic_service as svc

router = APIRouter(prefix="/acoustic", tags=["Acoustic"])

COLLECTION = "acoustic_results"
MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # same limit as the app


def _public(doc: dict) -> dict:
    """Fields returned to the app."""
    return {
        "id": doc["id"],
        "hive_id": doc["hive_id"],
        "apiary_id": doc.get("apiary_id"),
        "label": doc["label"],
        "confidence": doc["confidence"],
        "audio_quality": doc.get("audio_quality", "good"),
        "model_version": doc["model_version"],
        "analyzed_at": doc["created_at"],
        "clip_count": doc["clip_count"],
        "clip_probabilities": doc["clip_probabilities"],
        "source": doc["source"],
        "saved": doc.get("saved", False),
    }


def _own_result(result_id: str, user_id: str) -> dict:
    snap = db.collection(COLLECTION).document(result_id).get()
    data = snap.to_dict() if snap.exists else None
    # 404 for other users' results too, so ids cannot be probed.
    if not data or data.get("user_id") != user_id:
        raise HTTPException(status_code=404, detail="Result not found")
    return data


@router.get("/model-info")
def get_model_info():
    svc.load_model()
    return svc.model_info()


@router.post("/analyze")
def analyze(
    audio: UploadFile = File(...),
    hive_id: str = Form(...),
    source: str = Form("upload"),
    user_id: str = Depends(get_current_user_id),
):
    if source not in ("record", "upload"):
        raise HTTPException(status_code=400, detail='source must be "record" or "upload"')

    hive = db.collection("hives").document(hive_id).get()
    hive_data = hive.to_dict() if hive.exists else None
    if not hive_data:
        raise HTTPException(status_code=404, detail="Hive not found")
    if hive_data.get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Access denied")

    data = audio.file.read(MAX_UPLOAD_BYTES + 1)
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Audio file is too large (limit 10 MB)")

    try:
        out = svc.analyze_bytes(data)
    except svc.ModelUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except svc.AudioError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    result_id = str(uuid.uuid4())
    doc = {
        "id": result_id,
        "user_id": user_id,
        "apiary_id": hive_data.get("apiary_id"),
        "hive_id": hive_id,
        "label": out["label"],
        "confidence": out["confidence"],
        "queen_present_probability": out["queen_present_probability"],
        "clip_count": out["clip_count"],
        "clip_probabilities": out["clip_probabilities"],
        "audio_quality": out["audio_quality"],
        "source": source,
        "model_version": out["model_version"],
        "saved": False,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    db.collection(COLLECTION).document(result_id).set(doc)  # audio is never stored
    return _public(doc)


@router.post("/results/{result_id}/save")
def save_result(result_id: str, user_id: str = Depends(get_current_user_id)):
    data = _own_result(result_id, user_id)
    db.collection(COLLECTION).document(result_id).update({"saved": True})
    data["saved"] = True
    return _public(data)


@router.get("/history")
def get_history(
    hive_id: Optional[str] = Query(None),
    user_id: str = Depends(get_current_user_id),
):
    """Saved results of this user, newest first."""
    docs = db.collection(COLLECTION).where("user_id", "==", user_id).get()
    items = [d.to_dict() for d in docs if d.to_dict()]
    items = [
        d for d in items
        if d.get("saved") and (hive_id is None or d.get("hive_id") == hive_id)
    ]
    items.sort(key=lambda d: d.get("created_at", ""), reverse=True)
    return {"results": [_public(d) for d in items]}


@router.get("/results/{result_id}")
def get_result(result_id: str, user_id: str = Depends(get_current_user_id)):
    return _public(_own_result(result_id, user_id))
