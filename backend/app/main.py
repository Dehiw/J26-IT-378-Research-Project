
from fastapi import FastAPI
from app.firebase.firebase_config import db

app = FastAPI(
    title="Smart Beehive API",
    version="1.0.0"
)

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