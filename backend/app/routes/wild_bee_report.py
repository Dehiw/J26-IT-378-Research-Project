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
        "status": "Submitted",
        "assigned_beekeeper": None,
        "assigned_phone": None,
        "created_at": now_iso,
    }

    # Save to Firestore collection "wild_bee_reports"
    db.collection("wild_bee_reports").document(report_id).set(report_data)

    return WildBeeReportResponse(
        success=True,
        report_id=report_id,
        message="Wild bee hive report submitted successfully",
        status="Submitted",
        created_at=now_iso,
        address=request.address.strip(),
        gps_coordinates=request.gps_coordinates,
        colony_location=request.colony_location,
        height=request.height,
        inside_structure=request.inside_structure,
        safe_access=request.safe_access,
        assigned_beekeeper=None,
        assigned_phone=None,
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


@router.get("/{report_id}")
def get_report_by_id(report_id: str):
    """Retrieves a single wild bee hive report by its ID."""
    doc = db.collection("wild_bee_reports").document(report_id).get()
    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Report {report_id} not found."
        )
    return doc.to_dict()


@router.patch("/{report_id}/cancel")
def cancel_wild_bee_report(report_id: str):
    """Cancels a wild bee hive report if relocation has not started."""
    doc_ref = db.collection("wild_bee_reports").document(report_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Report {report_id} not found."
        )
    data = doc.to_dict()
    current_status = data.get("status", "")
    if current_status in ["In Progress", "Completed"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot cancel a request that is already {current_status}."
        )

    now_iso = datetime.now(timezone.utc).isoformat()
    doc_ref.update({
        "status": "Cancelled",
        "cancelled_at": now_iso,
    })
    data["status"] = "Cancelled"
    data["cancelled_at"] = now_iso
    return {
        "success": True,
        "message": f"Report {report_id} cancelled successfully.",
        "report": data,
    }


@router.patch("/{report_id}/status")
def update_report_status(
    report_id: str,
    status_str: str,
    beekeeper_name: Optional[str] = None,
    beekeeper_phone: Optional[str] = None,
):
    """Updates the status and optional beekeeper assignment of a report."""
    doc_ref = db.collection("wild_bee_reports").document(report_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Report {report_id} not found."
        )
    updates = {
        "status": status_str,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    if beekeeper_name:
        updates["assigned_beekeeper"] = beekeeper_name
    if beekeeper_phone:
        updates["assigned_phone"] = beekeeper_phone

    doc_ref.update(updates)
    data = doc_ref.get().to_dict()
    return {
        "success": True,
        "message": f"Report {report_id} updated to {status_str}.",
        "report": data,
    }

