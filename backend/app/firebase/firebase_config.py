import os
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

load_dotenv()

# BASE_DIR = backend/  (this file is backend/app/firebase/firebase_config.py)
BASE_DIR = Path(__file__).resolve().parents[2]

configured_cred_path = (
    os.getenv("FIREBASE_CREDENTIALS_PATH")
    or os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    or "firebase-service-account.json"
)
cred_path = Path(configured_cred_path)
if not cred_path.is_absolute():
    cred_path = BASE_DIR / cred_path

if not cred_path.is_file():
    raise FileNotFoundError(
        "Firebase service account is not configured. "
        "Set FIREBASE_CREDENTIALS_PATH in backend/.env."
    )

# Avoid 'app already exists' error on --reload
if not firebase_admin._apps:
    cred = credentials.Certificate(str(cred_path))
    firebase_admin.initialize_app(cred)

db = firestore.client()
