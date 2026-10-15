from typing import Optional
from pydantic import BaseModel, Field


class ApiarySetupRequest(BaseModel):
    location_name: str = Field(..., min_length=2, max_length=150)
    area_address: str = Field(..., min_length=2, max_length=200)
    gps_location: Optional[str] = None
    hive_name: str = Field(..., min_length=1, max_length=100)
    hive_type: str = Field(default="Langstroth")
    bee_species: str = Field(default="Apis cerana")
    num_frames: int = Field(default=8, ge=1, le=12)


class ApiarySetupResponse(BaseModel):
    success: bool = True
    message: str = "Apiary setup saved successfully"
    apiary_id: str
    hive_id: str


class CreateApiaryRequest(BaseModel):
    location_name: str = Field(..., min_length=2, max_length=150)
    area_address: str = Field(..., min_length=2, max_length=200)
    gps_location: Optional[str] = None


class CreateHiveRequest(BaseModel):
    apiary_id: str
    hive_name: str = Field(..., min_length=1, max_length=100)
    num_frames: int = Field(default=8, ge=1, le=12)
    hive_type: str = Field(default="Langstroth")
    bee_species: str = Field(default="Apis cerana")
    installation_date: Optional[str] = None
