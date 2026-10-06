# J26-IT-378 Research Project — Team Setup Guide

This guide explains what each team member should do after cloning the project from GitHub.

---

## 1. Clone the repository

```bash
git clone <your-repository-url>
cd J26-IT-378-Research-Project
```

---

## 2. Set up the Flutter frontend

Go to the frontend folder:

```bash
cd frontend
```

Install Flutter packages:

```bash
flutter pub get
```

Run the Flutter app:

```bash
flutter run
```

### Requirement
Flutter must already be installed on the computer.

---

## 3. Set up the Python backend

Go back to the project root, then enter the backend folder:

```bash
cd ../backend
```

Create a Python virtual environment:

```bash
python -m venv venv
```

### Activate the virtual environment

#### Git Bash

```bash
source venv/Scripts/activate
```

#### PowerShell

```powershell
venv\Scripts\Activate.ps1
```

When the virtual environment is active, you should see:

```text
(venv)
```

at the beginning of the terminal line.

---

## 4. Install backend packages

Run:

```bash
pip install -r requirements.txt
```

This installs the required backend packages such as:

- FastAPI
- Uvicorn
- Firebase Admin SDK
- ONNX Runtime
- NumPy
- python-dotenv

---

## 5. Add the Firebase service account file

The Firebase private key is NOT stored in GitHub because it is private.

Each team member needs the file:

```text
firebase-service-account.json
```

Place it inside:

```text
backend/
```

The structure should look like:

```text
backend/
├── app/
├── requirements.txt
├── firebase-service-account.json
└── venv/
```

### Important

Do NOT push `firebase-service-account.json` to GitHub.

It is already ignored by `.gitignore`.

The file should be shared privately with team members.

---

## 6. Run the FastAPI backend

Make sure you are inside the `backend` folder and the virtual environment is active.

Run:

```bash
uvicorn app.main:app --reload
```

If it works, FastAPI should run at:

```text
http://127.0.0.1:8000
```

Swagger API documentation:

```text
http://127.0.0.1:8000/docs
```

---

## 7. Current project setup

```text
J26-IT-378-Research-Project/
│
├── frontend/
│   └── Flutter mobile application
│
├── backend/
│   ├── app/
│   ├── requirements.txt
│   └── firebase-service-account.json   # private, not pushed
│
├── .gitignore
└── README.md
```

---

## 8. Files/folders that do NOT need to be shared

These are recreated automatically on each member's computer:

```text
venv/
.dart_tool/
build/
.idea/
```

Other ignored/private files such as `.env` and Firebase credentials should also not be committed.

---

## Quick setup summary

```text
Clone repository
      ↓
Flutter → flutter pub get
      ↓
Backend → python -m venv venv
      ↓
Activate venv
      ↓
pip install -r requirements.txt
      ↓
Add firebase-service-account.json privately
      ↓
Run FastAPI
      ↓
uvicorn app.main:app --reload
```
