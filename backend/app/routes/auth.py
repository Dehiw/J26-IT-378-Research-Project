from fastapi import APIRouter, Depends, HTTPException, Header, status
from typing import Optional

from app.schemas.auth import UserRegisterRequest, UserLoginRequest, AuthResponse, UserResponse
from app.services.auth_service import auth_service
from app.core.security import decode_access_token

router = APIRouter(prefix="/auth", tags=["Authentication"])


def get_current_user_id(authorization: Optional[str] = Header(None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization token required"
        )
    token = authorization.split(" ")[1]
    payload = decode_access_token(token)
    if not payload or "sub" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token"
        )
    return payload["sub"]


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def register(request: UserRegisterRequest):
    """Register a new beekeeper account and generate access token."""
    return auth_service.register(request)


@router.post("/login", response_model=AuthResponse)
def login(request: UserLoginRequest):
    """Authenticate with email and password to receive access token."""
    return auth_service.login(request)


@router.get("/me", response_model=UserResponse)
def get_current_profile(user_id: str = Depends(get_current_user_id)):
    """Retrieve current authenticated beekeeper's profile."""
    return auth_service.get_user_by_id(user_id)
