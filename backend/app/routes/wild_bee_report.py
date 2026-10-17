from datetime import datetime, timezone
import uuid
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Header, status

from app.firebase.firebase_config import db
from app.core.security import decode_access_token
from app.schemas.wild_bee_report import WildBeeReportCreate, WildBeeReportResponse

router = APIRouter(prefix="/wild-bee-reports", tags=["Wild Bee Hive Reports"])


def get_optional_user_id(authorization: Optional[str] = Header(None)) -> Optional[str]:
    if not authorization or not authorization.startswith("Bearer "):
        return None
    token = authorization.split(" ")[1]
    payload = decode_access_token(token)
    if not payload or "sub" not in payload:
        return None
    return payload["sub"]


@router.post("", response_model=WildBeeReportResponse, status_code=status.HTTP_201_CREATED)
def submit_wild_bee_report(
    request: WildBeeReportCreate,
    user_id: Optional[str] = Depends(get_optional_user_id)
):
    """
    Submits a new wild bee hive report and saves it to Firestore.
    Available to normal users (homeowners/citizens).
    """
    report_id = f"REL-{datetime.now().year}-{str(uuid.uuid4())[:6].upper()}"
    now_iso = datetime.now(timezone.utc).isoformat()

    user_name = "Community Member"
    user_email = ""

    if user_id:
        try:
            user_doc = db.collection("users").document(user_id).get()
            if user_doc.exists:
                data = user_doc.to_dict()
                user_name = data.get("name", user_name)
                user_email = data.get("email", user_email)
        except Exception:
            pass

    report_data = {
        "id": report_id,
        "user_id": user_id or "anonymous",
        "user_name": user_name,
        "user_email": user_email,
        "address": request.address.strip(),
        "gps_coordinates": request.gps_coordinates,
        "colony_location": request.colony_location,
        "height": request.height,
        "inside_structure": request.inside_structure,
        "safe_access": request.safe_access,
        "has_photo": request.has_photo,
        "photo_url": request.photo_url,
        "notes": request.notes,
        "status": "Pending Beekeeper Assignment",
        "created_at": now_iso,
    }

    # Save to Firestore collection "wild_bee_reports"
    db.collection("wild_bee_reports").document(report_id).set(report_data)

    return WildBeeReportResponse(
        success=True,
        report_id=report_id,
        message="Wild bee hive report submitted successfully",
        status="Pending Beekeeper Assignment",
        created_at=now_iso,
        address=request.address.strip(),
        gps_coordinates=request.gps_coordinates,
        colony_location=request.colony_location,
        height=request.height,
        inside_structure=request.inside_structure,
        safe_access=request.safe_access,
    )


@router.get("/my")
def get_my_reports(user_id: Optional[str] = Depends(get_optional_user_id)):
    """Retrieves reports submitted by the authenticated user or recent reports."""
    try:
        if user_id:
            docs = db.collection("wild_bee_reports").where("user_id", "==", user_id).get()
            reports = [d.to_dict() for d in docs]
        else:
            docs = db.collection("wild_bee_reports").limit(20).get()
            reports = [d.to_dict() for d in docs]

        # Sort in memory to avoid Firestore compound index requirement
        reports.sort(key=lambda r: r.get("created_at", ""), reverse=True)
        return {"reports": reports}
    except Exception as e:
        docs = db.collection("wild_bee_reports").limit(20).get()
        reports = [d.to_dict() for d in docs]
        reports.sort(key=lambda r: r.get("created_at", ""), reverse=True)
        return {"reports": reports}


@router.get("/all")
def get_all_reports():
    """Retrieves all wild bee hive reports for beekeepers to browse and claim."""
    try:
        docs = db.collection("wild_bee_reports").limit(100).get()
        reports = [d.to_dict() for d in docs]
        reports.sort(key=lambda r: r.get("created_at", ""), reverse=True)
        return {"reports": reports}
    except Exception:
        return {"reports": []}
