from typing import Optional, List
from pydantic import BaseModel, Field


class WildBeeReportCreate(BaseModel):
    address: str = Field(..., min_length=2, max_length=250)
    gps_coordinates: Optional[str] = None
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


class WildBeeStatusUpdate(BaseModel):
    status: str = Field(..., description="Submitted, Under Review, Waiting for Beekeeper, Accepted, Relocation Scheduled, In Progress, Completed, Cancelled")
    assigned_beekeeper: Optional[str] = None
    assigned_phone: Optional[str] = None
    notes: Optional[str] = None

