"""Loopback-only HTTP contract fixture, never a production application.

Uses explicit unavailable model states; does not access Firebase or WeatherAPI.
Run from backend: python -B tests/IT23183186_smoke_server.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from fastapi import FastAPI, Header, HTTPException
import uvicorn
from app.core.security import get_current_user_id
from app.routes.IT23183186_image_inference import router


class UnavailableModels:
    status = {key: {"available": False, "message": "HTTP contract test: no trained model installed."}
              for key in ("model_a", "model_b")}


def test_user(authorization: str = Header(default="")):
    if authorization != "Bearer integration-test-only":
        raise HTTPException(401, "Test token required")
    return "integration-test-user"


if __name__ == "__main__":
    app = FastAPI()
    app.include_router(router, prefix="/api/v1")
    app.state.image_model_service = UnavailableModels()
    app.dependency_overrides[get_current_user_id] = test_user
    uvicorn.run(app, host="127.0.0.1", port=8765)
