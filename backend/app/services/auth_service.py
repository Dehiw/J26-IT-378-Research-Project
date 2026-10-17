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

        phone = data.phone.strip() if data.phone else None

        user_dict = {
            "id": user_id,
            "name": data.name.strip(),
            "email": normalized_email,
            "phone": phone,
            "user_type": data.user_type.strip() if data.user_type else "Bee Keeper",
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
                phone_number=phone if phone and phone.startswith("+") else None,
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
            phone=phone,
            user_type=user_dict["user_type"],
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
            phone=user_data.get("phone"),
            user_type=user_data.get("user_type", "Bee Keeper"),
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
            phone=data.get("phone"),
            user_type=data.get("user_type", "Bee Keeper"),
            apiary_name=data.get("apiary_name"),
            created_at=data.get("created_at")
        )

    def get_registered_beekeepers(self):
        """Retrieves all registered users who are Bee Keepers."""
        try:
            docs = self.collection.where("user_type", "==", "Bee Keeper").get()
            beekeepers = []
            for doc in docs:
                d = doc.to_dict()
                beekeepers.append({
                    "id": d.get("id", doc.id),
                    "name": d.get("name", "Beekeeper"),
                    "email": d.get("email", ""),
                    "phone": d.get("phone", ""),
                    "apiary_name": d.get("apiary_name", "Registered Apiary"),
                    "user_type": d.get("user_type", "Bee Keeper"),
                    "created_at": d.get("created_at", ""),
                })
            # Sort newest registered first
            beekeepers.sort(key=lambda b: b.get("created_at", ""), reverse=True)
            return {"beekeepers": beekeepers}
        except Exception:
            return {"beekeepers": []}


auth_service = AuthService()

