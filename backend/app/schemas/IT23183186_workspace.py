from datetime import date, datetime, timedelta, timezone
from typing import Literal
from pydantic import BaseModel, Field, model_validator

class ColonyObservation(BaseModel):
    observed_on: date
    queen: Literal["seen", "eggs_seen", "not_seen", "not_checked"] = "not_checked"
    food_stores: Literal["light", "adequate", "heavy", "not_checked"] = "not_checked"
    brood: Literal["consistent", "patchy", "not_seen", "not_checked"] = "not_checked"
    bee_activity: Literal["low", "usual", "high", "not_checked"] = "not_checked"
    forage: Literal["observed", "not_observed", "not_checked"] = "not_checked"
    brood_frames: int | None = Field(None, ge=0, le=100)
    estimated_population: int | None = Field(None, ge=0, le=1000000)
    notes: str = Field("", max_length=2000)

    @model_validator(mode="after")
    def valid_observation(self):
        today = (datetime.now(timezone.utc) + timedelta(hours=5, minutes=30)).date()
        if self.observed_on > today:
            raise ValueError("Observation date cannot be in the future.")
        if all(getattr(self, k) == "not_checked" for k in ("queen", "food_stores", "brood", "bee_activity", "forage")) and not self.notes.strip() and self.brood_frames is None and self.estimated_population is None:
            raise ValueError("Record at least one observation.")
        return self

class CarePlan(BaseModel):
    action: Literal["inspect", "check_food", "monitor_mites", "verify_sensor", "contact_expert", "treatment_record"]
    due_on: date
    notes: str = Field("", max_length=2000)
    product: str = Field("", max_length=120)
    advisor: str = Field("", max_length=160)

    @model_validator(mode="after")
    def valid_plan(self):
        if not self.notes.strip(): raise ValueError("A care plan note is required.")
        if self.action == "treatment_record" and (not self.product.strip() or not self.advisor.strip()):
            raise ValueError("Record the advising expert and advised procedure.")
        return self

class MonitoringPreferences(BaseModel):
    auto_refresh: bool = True
    refresh_seconds: Literal[60, 300, 900] = 300
    in_app_alerts: bool = True

class AlertReview(BaseModel):
    key: str = Field(pattern=r"^[a-f0-9]{64}$")
