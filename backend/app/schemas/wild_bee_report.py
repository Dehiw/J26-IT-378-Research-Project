from typing import Optional, List, Literal
from pydantic import BaseModel, Field

# Where gps_coordinates came from. Only "device_gps" is a verified device fix.
LocationSource = Literal["device_gps", "manual_pin", "ip_approximate", "default_placeholder", "unknown"]


class WildBeeReportCreate(BaseModel):
    address: str = Field(..., min_length=2, max_length=250)
    gps_coordinates: Optional[str] = None
    location_source: LocationSource = "unknown"
    colony_location: str = Field(..., description="e.g. Roof, Wall, Tree, Other")
    height: str = Field(..., description="e.g. Below 2 m, 2–5 m, Above 5 m")
    inside_structure: str = Field(..., description="Yes, No, Not sure")
    safe_access: str = Field(..., description="Yes, No, Not sure")
    has_photo: bool = False
    photo_url: Optional[str] = None
    notes: Optional[str] = None
    assigned_beekeeper: Optional[str] = None
    assigned_phone: Optional[str] = None
    assigned_beekeeper_id: Optional[str] = None


class WildBeeReportResponse(BaseModel):
    success: bool = True
    report_id: str
    message: str = "Wild bee hive report submitted successfully"
    status: str = "Submitted"
    created_at: str
    address: str
    gps_coordinates: Optional[str] = None
    colony_location: str
    height: str
    inside_structure: str
    safe_access: str
    assigned_beekeeper: Optional[str] = None
    assigned_phone: Optional[str] = None
    # IT23185302 preliminary relocation assessment (optional for older clients)
    assessment_level: Optional[str] = None
    main_concerns: Optional[List[str]] = None
    recommended_action: Optional[str] = None
    assessment_source: Optional[str] = None
    model_name: Optional[str] = None
    requires_beekeeper_review: Optional[bool] = None
    homeowner_guidance: Optional[str] = None


class WildBeeAssessmentRequest(BaseModel):
    """Input for the preview endpoint; nothing is saved to Firestore."""
    address: Optional[str] = None
    gps_coordinates: Optional[str] = None
    location_source: LocationSource = "unknown"
    colony_location: str
    height: str
    inside_structure: str
    safe_access: str
    photo_url: Optional[str] = None
    notes: Optional[str] = None


class WildBeeAssessmentResponse(BaseModel):
    assessment_level: str
    main_concerns: List[str]
    recommended_action: str
    assessment_source: str
    model_name: str
    fallback_reason: Optional[str] = None
    requires_beekeeper_review: bool = True
    homeowner_guidance: str
    photo_analyzed: bool = False
    location_source: str
    assessed_at: str


class WildBeeStatusUpdate(BaseModel):
    status: str = Field(..., description="Submitted, Under Review, Waiting for Beekeeper, Accepted, Relocation Scheduled, In Progress, Completed, Cancelled")
    assigned_beekeeper: Optional[str] = None
    assigned_phone: Optional[str] = None
    notes: Optional[str] = None

