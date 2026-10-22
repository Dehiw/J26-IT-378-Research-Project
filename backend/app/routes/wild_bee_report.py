from datetime import datetime, timezone
import uuid
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Header, status

from app.firebase.firebase_config import db
from app.core.security import decode_access_token, get_current_user_id
from app.schemas.wild_bee_report import (
    WildBeeAssessmentRequest,
    WildBeeAssessmentResponse,
    WildBeeReportCreate,
    WildBeeReportResponse,
)
from app.services.IT23185302_relocation_risk_service import (
    assess_relocation_risk,
    prepare_photo,
    HOMEOWNER_SAFETY_NOTE,
    rule_based_assessment,
    RULE_BASED_MODEL_NAME,
    SOURCE_RULE_BASED,
)

router = APIRouter(prefix="/wild-bee-reports", tags=["Wild Bee Hive Reports"])

ASSESSMENT_KEYS = (
    "assessment_level",
    "main_concerns",
    "recommended_action",
    "assessment_source",
    "model_name",
    "fallback_reason",
    "requires_beekeeper_review",
    "homeowner_guidance",
    "photo_analyzed",
    "assessed_at",
)


def _run_assessment(answers: dict, location: dict, photo_data_url: Optional[str]):
    """Prepare the photo and run the IT23185302 assessment; never raises."""
    photo = None
    try:
        photo = prepare_photo(photo_data_url)
        assessment = assess_relocation_risk(answers, location, photo)
    except Exception as exc:
        assessment = {
            **rule_based_assessment(answers),
            "assessment_source": SOURCE_RULE_BASED,
            "model_name": RULE_BASED_MODEL_NAME,
            "fallback_reason": f"Assessment error ({type(exc).__name__})",
            "requires_beekeeper_review": True,
            "homeowner_guidance": HOMEOWNER_SAFETY_NOTE,
            "photo_analyzed": False,
            "location_source": location.get("location_source") or "unknown",
            "assessed_at": datetime.now(timezone.utc).isoformat(),
        }
    return photo, assessment


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

    answers = {
        "colony_location": request.colony_location,
        "height": request.height,
        "inside_structure": request.inside_structure,
        "safe_access": request.safe_access,
        "notes": request.notes,
    }
    location = {
        "address": request.address.strip(),
        "gps_coordinates": request.gps_coordinates,
        "location_source": request.location_source,
    }
    photo, assessment = _run_assessment(answers, location, request.photo_url)

    # Store only the compressed photo so the document stays under Firestore's 1 MiB cap.
    stored_photo_url = photo.data_url if photo else None
    photo_storage_note = None
    if request.photo_url and not stored_photo_url:
        photo_storage_note = (
            photo.storage_note if photo and photo.storage_note
            else "Photo could not be processed and was not stored."
        )

    report_data = {
        "id": report_id,
        "user_id": user_id or "anonymous",
        "user_name": user_name,
        "user_email": user_email,
        "address": request.address.strip(),
        "gps_coordinates": request.gps_coordinates,
        "location_source": request.location_source,
        "colony_location": request.colony_location,
        "height": request.height,
        "inside_structure": request.inside_structure,
        "safe_access": request.safe_access,
        "has_photo": request.has_photo,
        "photo_url": stored_photo_url,
        "photo_storage_note": photo_storage_note,
        "notes": request.notes,
        **{k: assessment.get(k) for k in ASSESSMENT_KEYS},
        "status": "Accepted" if request.assigned_beekeeper else "Submitted",
        "assigned_beekeeper": request.assigned_beekeeper,
        "assigned_phone": request.assigned_phone,
        "assigned_beekeeper_id": request.assigned_beekeeper_id,
        "created_at": now_iso,
    }

    # Save to Firestore collection "wild_bee_reports"
    db.collection("wild_bee_reports").document(report_id).set(report_data)

    return WildBeeReportResponse(
        success=True,
        report_id=report_id,
        message="Wild bee hive report submitted successfully",
        status="Accepted" if request.assigned_beekeeper else "Submitted",
        created_at=now_iso,
        address=request.address.strip(),
        gps_coordinates=request.gps_coordinates,
        colony_location=request.colony_location,
        height=request.height,
        inside_structure=request.inside_structure,
        safe_access=request.safe_access,
        assigned_beekeeper=request.assigned_beekeeper,
        assigned_phone=request.assigned_phone,
        assessment_level=assessment.get("assessment_level"),
        main_concerns=assessment.get("main_concerns"),
        recommended_action=assessment.get("recommended_action"),
        assessment_source=assessment.get("assessment_source"),
        model_name=assessment.get("model_name"),
        requires_beekeeper_review=assessment.get("requires_beekeeper_review"),
        homeowner_guidance=assessment.get("homeowner_guidance"),
    )


@router.post("/assess", response_model=WildBeeAssessmentResponse)
def preview_relocation_assessment(
    request: WildBeeAssessmentRequest,
    _user_id: str = Depends(get_current_user_id),
):
    """
    IT23185302 test endpoint: runs the preliminary relocation assessment
    without saving anything to Firestore. Requires a bearer token because it
    can call a paid hosted model.
    """
    answers = {
        "colony_location": request.colony_location,
        "height": request.height,
        "inside_structure": request.inside_structure,
        "safe_access": request.safe_access,
        "notes": request.notes,
    }
    location = {
        "address": request.address,
        "gps_coordinates": request.gps_coordinates,
        "location_source": request.location_source,
    }
    _photo, assessment = _run_assessment(answers, location, request.photo_url)
    return WildBeeAssessmentResponse(**assessment)


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


@router.patch("/{report_id}/assign-beekeeper")
def assign_beekeeper_to_report(
    report_id: str,
    beekeeper_name: str,
    beekeeper_phone: Optional[str] = None,
    beekeeper_id: Optional[str] = None,
):
    """Assigns a selected beekeeper to an existing report."""
    doc_ref = db.collection("wild_bee_reports").document(report_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Report {report_id} not found."
        )
    updates = {
        "status": "Accepted",
        "assigned_beekeeper": beekeeper_name,
        "assigned_phone": beekeeper_phone or "",
        "assigned_beekeeper_id": beekeeper_id or "",
        "assigned_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    doc_ref.update(updates)
    data = doc_ref.get().to_dict()
    return {
        "success": True,
        "message": f"Beekeeper {beekeeper_name} successfully assigned to report {report_id}.",
        "report": data,
    }


@router.patch("/{report_id}/manage")
def manage_wild_bee_report(report_id: str, payload: dict):
    """
    Updates relocation lifecycle fields for a report:
    Status (Accepted, Declined, Scheduled, In Progress, Completed),
    scheduling date/time, notes, and completion photos.
    Updates Firestore immediately.
    """
    doc_ref = db.collection("wild_bee_reports").document(report_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Report {report_id} not found."
        )

    allowed_keys = {
        "status",
        "assigned_beekeeper",
        "assigned_phone",
        "assigned_beekeeper_id",
        "scheduled_date",
        "scheduled_time",
        "notes",
        "relocation_notes",
        "completion_notes",
        "completion_photos",
        "declined_reason",
    }
    updates = {}
    for k, v in payload.items():
        if k in allowed_keys and v is not None:
            updates[k] = v

    updates["updated_at"] = datetime.now(timezone.utc).isoformat()
    doc_ref.update(updates)
    data = doc_ref.get().to_dict()
    return {
        "success": True,
        "message": f"Report {report_id} updated successfully.",
        "report": data,
    }


