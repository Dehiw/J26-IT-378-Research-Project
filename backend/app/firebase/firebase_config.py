import os
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

load_dotenv()

# BASE_DIR = backend/  (this file is backend/app/firebase/firebase_config.py)
BASE_DIR = Path(__file__).resolve().parents[2]

cred_path = (
    os.getenv("FIREBASE_CREDENTIALS_PATH")
    or os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    or str(BASE_DIR / "firebase-service-account.json")
)

if not os.path.isfile(cred_path):
    raise FileNotFoundError(
        f"Firebase service account not found at: {cred_path}\n"
        "Set FIREBASE_CREDENTIALS_PATH in backend/.env "
        "or place firebase-service-account.json in backend/"
    )

# Avoid 'app already exists' error on --reload
if not firebase_admin._apps:
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)

db = firestore.client()
