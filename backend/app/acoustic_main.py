# TEMPORARY: wraps the team app and adds the acoustic router without editing
# app/main.py. Remove this file once the team agrees to add
#   app.include_router(acoustic_router, prefix="/api/v1")
# to app/main.py. Run with:  uvicorn app.acoustic_main:app --reload
# (uvicorn app.main:app keeps working unchanged for everyone else.)

from app.main import app  # all team routes, CORS and the Firebase setup
from app.routes.acoustic import router as acoustic_router
from app.services import acoustic_service

app.include_router(acoustic_router, prefix="/api/v1")


# Load the model once at startup. Never fails startup: a missing model or
# library only makes /analyze return 503.
acoustic_service.load_model()
