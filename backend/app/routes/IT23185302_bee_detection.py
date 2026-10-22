"""IT23185302 bee detection endpoints (post-relocation camera monitoring).

POST /bee-detection/detect accepts one image as multipart field ``image``.
Today the image comes from the Flutter upload flow (source="upload"); the
ESP32-CAM is expected to post frames to the same endpoint later
(source="esp32cam"). No camera streaming is implemented yet.
"""

from __future__ import annotations

from typing import Literal, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from starlette.concurrency import run_in_threadpool

from app.core.security import get_current_user_id
from app.services.IT23185302_bee_detection_service import (
    MAX_IMAGE_BYTES,
    BeeDetectionService,
    decode_bee_image,
)

router = APIRouter(prefix="/bee-detection", tags=["IT23185302 Bee Detection"])


def _service(request: Request) -> BeeDetectionService:
    return request.app.state.bee_detection_service


@router.get("/status")
def bee_detection_status(request: Request, _user_id: str = Depends(get_current_user_id)):
    service = _service(request)
    return {**service.status, "model": service.describe()}


@router.post("/detect")
async def detect_bees(
    request: Request,
    image: UploadFile = File(...),
    source: Literal["upload", "esp32cam"] = Form("upload"),
    hive_id: Optional[str] = Form(None),
    _user_id: str = Depends(get_current_user_id),
):
    service = _service(request)
    data = await image.read(MAX_IMAGE_BYTES + 1)
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image exceeds the 10 MB limit.")
    try:
        decoded = decode_bee_image(data)
    except ValueError as exc:
        raise HTTPException(status_code=415, detail=str(exc)) from exc
    if not service.status["available"]:
        raise HTTPException(status_code=503, detail=service.status["message"])
    try:
        return await run_in_threadpool(service.detect, decoded, source, hive_id)
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Bee detection failed while running the model.") from exc
