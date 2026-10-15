from datetime import datetime, timezone
import uuid
from fastapi import APIRouter, Depends, HTTPException, status

from app.firebase.firebase_config import db
from app.routes.auth import get_current_user_id
from app.schemas.apiary import ApiarySetupRequest, ApiarySetupResponse

router = APIRouter(prefix="/apiary", tags=["Apiary Setup"])


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

    # 1. Store Apiary Location (also includes hive summary for easy inspection)
    apiary_doc = {
        "id": apiary_id,
        "user_id": user_id,
        "location_name": request.location_name.strip(),
        "area_address": request.area_address.strip(),
        "gps_location": request.gps_location,
        "hive_name": hive_name,
        "total_hives": next_index,
        "created_at": now_iso,
    }
    db.collection("apiaries").document(apiary_id).set(apiary_doc)

    # 2. Store Hive Box in 'hives' collection
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

    # 3. Update User Document with setup_completed flag
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
