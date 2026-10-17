from typing import Optional
from pydantic import BaseModel, Field

EMAIL_PATTERN = r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$"


class UserRegisterRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    email: str = Field(..., pattern=EMAIL_PATTERN, description="Valid email address")
    password: str = Field(..., min_length=6, max_length=128)
    user_type: Optional[str] = Field("Bee Keeper", description="'Normal user' or 'Bee Keeper'")
    apiary_name: Optional[str] = None


class UserLoginRequest(BaseModel):
    email: str = Field(..., pattern=EMAIL_PATTERN, description="Valid email address")
    password: str = Field(..., min_length=1)


class UserResponse(BaseModel):
    id: str
    name: str
    email: str
    user_type: Optional[str] = "Bee Keeper"
    apiary_name: Optional[str] = None
    created_at: Optional[str] = None


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
    message: Optional[str] = None
