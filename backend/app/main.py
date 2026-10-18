
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.firebase.firebase_config import db
from app.routes.auth import router as auth_router
from app.routes.apiary import router as apiary_router
from app.routes.environment import router as environment_router

app = FastAPI(
    title="Smart Beehive API",
    version="1.0.0"
)

# Enable CORS for Flutter mobile, web, and emulator clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Authentication & Setup endpoints
app.include_router(auth_router, prefix="/api/v1")
app.include_router(apiary_router, prefix="/api/v1")
app.include_router(environment_router, prefix="/api/v1")

@app.get("/")
def home():
    return {
        "message": "Smart Beehive backend is running"
    }

@app.get("/firebase-test")
def firebase_test():
    doc_ref = db.collection("test").document("connection")
    doc_ref.set({
        "status": "connected"
    })

    return {
        "message": "Firestore connected successfully"
    }