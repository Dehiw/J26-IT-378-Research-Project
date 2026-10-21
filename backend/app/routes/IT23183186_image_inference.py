"""Authenticated image inference endpoints for the two research models."""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from app.routes.IT23183186_environment import build_assessment
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


@router.get("/reports/{model_key}")
def reports(model_key: str, request: Request, _user_id: str = Depends(get_current_user_id)):
    if model_key not in ("model_a", "model_b"):
        raise HTTPException(404, "Unknown model.")
    from app.services.IT23183186_model_reports import model_report
    loaded = getattr(_service(request), "models", {}).get(model_key, {})
    return model_report(model_key, loaded.get("checkpoint"))


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
    q: str | None = Form(default=None, min_length=2, max_length=160),
    hive_id: str | None = Form(default=None, min_length=1, max_length=128, pattern=r"^[^/]+$"),
    save_result: bool = Form(default=False),
    _user_id: str = Depends(get_current_user_id),
):
    if save_result and not hive_id:
        raise HTTPException(422, "Select a hive before saving image findings.")
    if outside_image is None and inside_image is None:
        raise HTTPException(status_code=422, detail="Upload an outside-hive image, an inside-hive image, or both.")
    if hive_id:
        from app.services import IT23183186_environment_history as history
        saved_location = await run_in_threadpool(history.hive_location, hive_id, _user_id)
        q = q or saved_location
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
    for key, decoded in (("model_a", outside), ("model_b", inside)):
        if decoded is not None and response[key] is not None:
            response[key]["image_identifier"] = str(uuid4())
            response[key]["image_dimensions"] = list(decoded.size)
            if response[key].get("status") == "complete":
                response[key]["inference_timestamp"] = datetime.now(timezone.utc).isoformat()
    if q or hive_id:
        response.update(await build_assessment(q, hive_id, _user_id, response["model_a"], response["model_b"]))
    else:
        from app.services.IT23183186_colony_assessment import assess_colony
        response["assessment"] = assess_colony(model_a=response["model_a"], model_b=response["model_b"])
    if save_result:
        try:
            from app.services import IT23183186_environment_history as history
            snapshot = {**response, "record_type": "image_assessment",
                "image_inputs": {"individual_bee": outside is not None, "hive_frame": inside is not None},
                "image_storage": "Analysis only; original photos are not retained."}
            saved = await run_in_threadpool(history.save_snapshot, hive_id, _user_id, q, snapshot, "image_assessment_location")
            response["saved_record_id"] = saved["id"]
        except Exception:
            response["save_error"] = "Analysis completed, but its history record could not be saved."
    return response
