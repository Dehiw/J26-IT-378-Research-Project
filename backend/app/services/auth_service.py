from datetime import datetime, timezone
import uuid
from fastapi import HTTPException, status
from firebase_admin import auth as fb_auth

from app.firebase.firebase_config import db
from app.core.security import hash_password, verify_password, create_access_token
from app.schemas.auth import UserRegisterRequest, UserLoginRequest, UserResponse, AuthResponse


class AuthService:
    def __init__(self):
        self.collection = db.collection("users")

    def register(self, data: UserRegisterRequest) -> AuthResponse:
        normalized_email = data.email.strip().lower()

        # Check if user already exists in Firestore
        existing_docs = self.collection.where("email", "==", normalized_email).limit(1).get()
        if len(existing_docs) > 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="An account with this email address already exists"
            )

        user_id = str(uuid.uuid4())
        now_iso = datetime.now(timezone.utc).isoformat()
        pwd_hash = hash_password(data.password)

        user_dict = {
            "id": user_id,
            "name": data.name.strip(),
            "email": normalized_email,
            "apiary_name": data.apiary_name.strip() if data.apiary_name else None,
            "password_hash": pwd_hash,
            "created_at": now_iso,
        }

        # 1. Save to Firestore
        self.collection.document(user_id).set(user_dict)

        # 2. Optionally mirror to Firebase Auth for consolidated management
        try:
            fb_auth.create_user(
                uid=user_id,
                email=normalized_email,
                display_name=data.name.strip()
            )
        except Exception:
            # If Firebase Auth is not configured or user exists there, Firestore auth still functions
            pass

        # 3. Create session token
        token = create_access_token({
            "sub": user_id,
            "email": normalized_email,
            "name": data.name.strip()
        })

        user_res = UserResponse(
            id=user_id,
            name=data.name.strip(),
            email=normalized_email,
            apiary_name=user_dict["apiary_name"],
            created_at=now_iso
        )

        return AuthResponse(
            access_token=token,
            token_type="bearer",
            user=user_res,
            message="Account registered successfully"
        )

    def login(self, data: UserLoginRequest) -> AuthResponse:
        normalized_email = data.email.strip().lower()

        docs = self.collection.where("email", "==", normalized_email).limit(1).get()
        if len(docs) == 0:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )

        user_data = docs[0].to_dict()
        user_id = user_data.get("id") or docs[0].id
        stored_hash = user_data.get("password_hash")

        if not stored_hash or not verify_password(data.password, stored_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )

        token = create_access_token({
            "sub": user_id,
            "email": normalized_email,
            "name": user_data.get("name", "")
        })

        user_res = UserResponse(
            id=user_id,
            name=user_data.get("name", ""),
            email=normalized_email,
            apiary_name=user_data.get("apiary_name"),
            created_at=user_data.get("created_at")
        )

        return AuthResponse(
            access_token=token,
            token_type="bearer",
            user=user_res,
            message="Signed in successfully"
        )

    def get_user_by_id(self, user_id: str) -> UserResponse:
        doc = self.collection.document(user_id).get()
        if not doc.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        data = doc.to_dict()
        return UserResponse(
            id=user_id,
            name=data.get("name", ""),
            email=data.get("email", ""),
            apiary_name=data.get("apiary_name"),
            created_at=data.get("created_at")
        )


auth_service = AuthService()
