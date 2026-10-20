from fastapi import APIRouter, Depends, HTTPException, status

from app.schemas.auth import UserRegisterRequest, UserLoginRequest, AuthResponse, UserResponse
from app.services.auth_service import auth_service
from app.core.security import get_current_user_id

router = APIRouter(prefix="/auth", tags=["Authentication"])


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


@router.get("/beekeepers")
def get_registered_beekeepers():
    """Retrieve all registered users who have registered as Bee Keepers."""
    return auth_service.get_registered_beekeepers()

