from datetime import datetime, timezone
import uuid
from fastapi import APIRouter, Depends, HTTPException, status

from app.firebase.firebase_config import db
from app.routes.auth import get_current_user_id
from app.schemas.apiary import (
    ApiarySetupRequest, ApiarySetupResponse,
    CreateApiaryRequest, CreateHiveRequest
)

router = APIRouter(prefix="/apiary", tags=["Apiary Setup"])


# ── First-time Setup ──────────────────────────────────────────────

@router.get("/next-hive-number")
def get_next_hive_number(user_id: str = Depends(get_current_user_id)):
    """Returns the count of existing hives and the next suggested box name."""
    existing = db.collection("hives").where("user_id", "==", user_id).get()
    count = len(existing)
    next_num = count + 1
    return {
        "count": count,
        "next_number": next_num,
        "suggested_name": f"Hive Box #{next_num:02d}"
    }


@router.post("/setup", response_model=ApiarySetupResponse, status_code=status.HTTP_201_CREATED)
def setup_apiary(
    request: ApiarySetupRequest,
    user_id: str = Depends(get_current_user_id)
):
    """Save apiary, hive, and frames setup with automatic box numbering."""
    apiary_id = str(uuid.uuid4())
    hive_id = str(uuid.uuid4())
    now_iso = datetime.now(timezone.utc).isoformat()

    # Determine automatic box numbering (e.g. Hive Box #01, Hive Box #02, etc.)
    existing_hives = db.collection("hives").where("user_id", "==", user_id).get()
    next_index = len(existing_hives) + 1
    fallback_name = f"Hive Box #{next_index:02d}"
    hive_name = request.hive_name.strip() if request.hive_name and request.hive_name.strip() else fallback_name

    # 1. Store Apiary Location
    apiary_doc = {
        "id": apiary_id,
        "user_id": user_id,
        "location_name": request.location_name.strip(),
        "area_address": request.area_address.strip(),
        "gps_location": request.gps_location,
        "hive_name": hive_name,
        "total_hives": 1,
        "total_frames": request.num_frames,
        "status": "Active",
        "created_at": now_iso,
    }
    db.collection("apiaries").document(apiary_id).set(apiary_doc)

    # 2. Store Hive Box
    hive_doc = {
        "id": hive_id,
        "user_id": user_id,
        "apiary_id": apiary_id,
        "name": hive_name,
        "box_number": next_index,
        "hive_type": request.hive_type,
        "bee_species": request.bee_species,
        "num_frames": request.num_frames,
        "status": "Healthy",
        "created_at": now_iso,
    }
    db.collection("hives").document(hive_id).set(hive_doc)

    # 3. Auto-generate frame records
    for i in range(1, request.num_frames + 1):
        frame_doc = {
            "id": str(uuid.uuid4()),
            "hive_id": hive_id,
            "apiary_id": apiary_id,
            "user_id": user_id,
            "frame_number": i,
            "status": "Active",
            "created_at": now_iso,
        }
        db.collection("frames").add(frame_doc)

    # 4. Update User Document
    db.collection("users").document(user_id).update({
        "setup_completed": True,
        "primary_apiary_id": apiary_id,
        "total_hives": next_index,
        "updated_at": now_iso,
    })

    return ApiarySetupResponse(
        success=True,
        message=f"{hive_name} configured successfully",
        apiary_id=apiary_id,
        hive_id=hive_id
    )


# ── Apiary Management ──────────────────────────────────────────────

@router.get("/list")
def list_apiaries(user_id: str = Depends(get_current_user_id)):
    """Get all apiaries for the current user."""
    docs = db.collection("apiaries").where("user_id", "==", user_id).get()
    apiaries = []
    for doc in docs:
        data = doc.to_dict() or {}
        # Count hives and frames for this apiary
        hives = db.collection("hives").where("apiary_id", "==", data.get("id", "")).get()
        total_frames = sum((h.to_dict() or {}).get("num_frames", 0) for h in hives)
        data["total_hives"] = len(hives)
        data["total_frames"] = total_frames
        apiaries.append(data)
    return {"apiaries": apiaries}


@router.post("/create", status_code=status.HTTP_201_CREATED)
def create_apiary(
    request: CreateApiaryRequest,
    user_id: str = Depends(get_current_user_id)
):
    """Create a new apiary location for the current user."""
    apiary_id = str(uuid.uuid4())
    now_iso = datetime.now(timezone.utc).isoformat()

    apiary_doc = {
        "id": apiary_id,
        "user_id": user_id,
        "location_name": request.location_name.strip(),
        "area_address": request.area_address.strip(),
        "gps_location": request.gps_location,
        "total_hives": 0,
        "total_frames": 0,
        "status": "Active",
        "created_at": now_iso,
    }
    db.collection("apiaries").document(apiary_id).set(apiary_doc)
    return {"success": True, "apiary": apiary_doc}


# ── Hive Box Management ────────────────────────────────────────────

@router.get("/{apiary_id}/hives")
def list_hives(apiary_id: str, user_id: str = Depends(get_current_user_id)):
    """Get all hive boxes for a specific apiary."""
    # Verify apiary belongs to user
    apiary_doc = db.collection("apiaries").document(apiary_id).get()
    if not apiary_doc.exists:
        raise HTTPException(status_code=404, detail="Apiary not found")
    apiary_data = apiary_doc.to_dict() or {}
    if apiary_data.get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Access denied")

    docs = db.collection("hives").where("apiary_id", "==", apiary_id).get()
    hives = [doc.to_dict() for doc in docs if doc.to_dict()]
    return {"hives": hives}


@router.get("/{apiary_id}/next-hive-number")
def get_next_hive_number_for_apiary(
    apiary_id: str,
    user_id: str = Depends(get_current_user_id)
):
    """Returns the next suggested hive box name for a specific apiary."""
    existing = db.collection("hives").where("apiary_id", "==", apiary_id).get()
    count = len(existing)
    next_num = count + 1
    return {
        "count": count,
        "next_number": next_num,
        "suggested_name": f"Hive Box #{next_num:02d}"
    }


@router.post("/hive/create", status_code=status.HTTP_201_CREATED)
def create_hive(
    request: CreateHiveRequest,
    user_id: str = Depends(get_current_user_id)
):
    """Create a new hive box under an apiary and auto-generate frame records."""
    # Verify apiary belongs to user
    apiary_doc = db.collection("apiaries").document(request.apiary_id).get()
    if not apiary_doc.exists:
        raise HTTPException(status_code=404, detail="Apiary not found")
    apiary_data = apiary_doc.to_dict() or {}
    if apiary_data.get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Access denied")

    hive_id = str(uuid.uuid4())
    now_iso = datetime.now(timezone.utc).isoformat()

    # Auto-number within this apiary
    existing = db.collection("hives").where("apiary_id", "==", request.apiary_id).get()
    box_number = len(existing) + 1
    hive_name = request.hive_name.strip() or f"Hive Box #{box_number:02d}"

    hive_doc = {
        "id": hive_id,
        "user_id": user_id,
        "apiary_id": request.apiary_id,
        "name": hive_name,
        "box_number": box_number,
        "hive_type": request.hive_type,
        "bee_species": request.bee_species,
        "num_frames": request.num_frames,
        "status": "Healthy",
        "installation_date": request.installation_date,
        "created_at": now_iso,
    }
    db.collection("hives").document(hive_id).set(hive_doc)

    # Auto-generate frame records
    for i in range(1, request.num_frames + 1):
        frame_doc = {
            "id": str(uuid.uuid4()),
            "hive_id": hive_id,
            "apiary_id": request.apiary_id,
            "user_id": user_id,
            "frame_number": i,
            "status": "Active",
            "created_at": now_iso,
        }
        db.collection("frames").add(frame_doc)

    # Update apiary totals
    db.collection("apiaries").document(request.apiary_id).update({
        "total_hives": box_number,
        "total_frames": (apiary_data.get("total_frames") or 0) + request.num_frames,
        "updated_at": now_iso,
    })

    return {"success": True, "hive": hive_doc}


# ── Status ─────────────────────────────────────────────────────────

@router.get("/status")
def check_setup_status(user_id: str = Depends(get_current_user_id)):
    """Check if the authenticated user has completed their first-time setup."""
    user_doc = db.collection("users").document(user_id).get()
    if not user_doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    data = user_doc.to_dict() or {}
    completed = data.get("setup_completed", False)
    return {
        "setup_completed": completed,
        "primary_apiary_id": data.get("primary_apiary_id")
    }
