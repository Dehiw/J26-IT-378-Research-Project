"""Authenticated image inference endpoints for the two research models."""

from __future__ import annotations

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from starlette.concurrency import run_in_threadpool

from app.core.security import get_current_user_id
from app.services.IT23183186_image_model_service import MAX_IMAGE_BYTES, ImageModelService, decode_image

router = APIRouter(prefix="/inference", tags=["Image inference"])


async def _read_image(upload: UploadFile | None):
    if upload is None:
        return None
    data = await upload.read(MAX_IMAGE_BYTES + 1)
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image exceeds the 10 MB limit.")
    try:
        return decode_image(data)
    except ValueError as exc:
        raise HTTPException(status_code=415, detail=str(exc)) from exc


def _service(request: Request) -> ImageModelService:
    return request.app.state.image_model_service


def _unavailable(service: ImageModelService, key: str) -> dict:
    return {"status": "unavailable", "message": service.status[key]["message"]}


@router.get("/status")
def model_status(request: Request, _user_id: str = Depends(get_current_user_id)):
    service = _service(request)
    return {"model_a": service.status["model_a"], "model_b": service.status["model_b"]}


@router.post("/outside-hive")
async def outside_hive(
    request: Request,
    image: UploadFile = File(...),
    _user_id: str = Depends(get_current_user_id),
):
    service = _service(request)
    decoded = await _read_image(image)
    if not service.status["model_a"]["available"]:
        raise HTTPException(status_code=503, detail=service.status["model_a"]["message"])
    try:
        return {"model_a": await run_in_threadpool(service.predict_a, decoded)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Model A inference failed.") from exc


@router.post("/inside-hive")
async def inside_hive(
    request: Request,
    image: UploadFile = File(...),
    _user_id: str = Depends(get_current_user_id),
):
    service = _service(request)
    decoded = await _read_image(image)
    if not service.status["model_b"]["available"]:
        raise HTTPException(status_code=503, detail=service.status["model_b"]["message"])
    try:
        return {"model_b": await run_in_threadpool(service.predict_b, decoded)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Model B inference failed.") from exc


@router.post("/analyze")
async def analyze_images(
    request: Request,
    outside_image: UploadFile | None = File(default=None),
    inside_image: UploadFile | None = File(default=None),
    _user_id: str = Depends(get_current_user_id),
):
    if outside_image is None and inside_image is None:
        raise HTTPException(status_code=422, detail="Upload an outside-hive image, an inside-hive image, or both.")
    service = _service(request)
    outside = await _read_image(outside_image)
    inside = await _read_image(inside_image)
    response = {"model_a": None, "model_b": None}
    if outside is not None:
        if service.status["model_a"]["available"]:
            try:
                response["model_a"] = {"status": "complete", **await run_in_threadpool(service.predict_a, outside)}
            except Exception:
                response["model_a"] = {"status": "error", "message": "Model A inference failed."}
        else:
            response["model_a"] = _unavailable(service, "model_a")
    if inside is not None:
        if service.status["model_b"]["available"]:
            try:
                response["model_b"] = {"status": "complete", **await run_in_threadpool(service.predict_b, inside)}
            except Exception:
                response["model_b"] = {"status": "error", "message": "Model B inference failed."}
        else:
            response["model_b"] = _unavailable(service, "model_b")
    return response
