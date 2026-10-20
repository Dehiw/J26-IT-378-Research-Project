from io import BytesIO

from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image

from app.core.security import get_current_user_id
from app.routes.image_inference import router


class StubImageModels:
    status = {
        "model_a": {"available": True, "message": "ready"},
        "model_b": {"available": True, "message": "ready"},
    }

    def predict_a(self, image):
        return {
            "predicted_class": "healthy",
            "class_scores": {"healthy": 0.8, "varroa_positive": 0.2},
            "model_version": "test-model-a",
            "limitations": ["Test stub only; not a diagnosis."],
        }

    def predict_b(self, image):
        return {
            "detections": [{"class_name": "BeeHiveFrame", "bbox_xyxy": [0, 0, 8, 8], "confidence": 0.9}],
            "model_version": "test-model-b",
            "limitations": ["Structural labels only."],
        }


def make_client(*, authenticated=True):
    app = FastAPI()
    app.include_router(router, prefix="/api/v1")
    app.state.image_model_service = StubImageModels()
    if authenticated:
        app.dependency_overrides[get_current_user_id] = lambda: "test-user"
    return TestClient(app)


def image_upload():
    output = BytesIO()
    Image.new("RGB", (8, 8), color="white").save(output, format="PNG")
    return output.getvalue()


def test_outside_hive_endpoint_returns_model_a_contract():
    response = make_client().post(
        "/api/v1/inference/outside-hive",
        files={"image": ("outside.png", image_upload(), "image/png")},
    )
    assert response.status_code == 200
    assert response.json()["model_a"]["predicted_class"] == "healthy"


def test_inside_hive_endpoint_returns_box_detections():
    response = make_client().post(
        "/api/v1/inference/inside-hive",
        files={"image": ("frame.png", image_upload(), "image/png")},
    )
    assert response.status_code == 200
    detection = response.json()["model_b"]["detections"][0]
    assert detection["class_name"] == "BeeHiveFrame"
    assert len(detection["bbox_xyxy"]) == 4


def test_combined_request_keeps_model_outputs_separate():
    response = make_client().post(
        "/api/v1/inference/analyze",
        files={
            "outside_image": ("outside.png", image_upload(), "image/png"),
            "inside_image": ("inside.png", image_upload(), "image/png"),
        },
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["model_a"]["predicted_class"] == "healthy"
    assert payload["model_b"]["detections"]


def test_combined_request_allows_either_image_independently():
    response = make_client().post(
        "/api/v1/inference/analyze",
        files={"inside_image": ("inside.png", image_upload(), "image/png")},
    )
    assert response.status_code == 200
    assert response.json()["model_a"] is None
    assert response.json()["model_b"]["status"] == "complete"


def test_combined_request_rejects_no_photos_and_corrupt_images():
    client = make_client()
    assert client.post("/api/v1/inference/analyze").status_code == 422
    response = client.post(
        "/api/v1/inference/outside-hive",
        files={"image": ("bad.png", b"not an image", "image/png")},
    )
    assert response.status_code == 415


def test_image_format_and_size_limits_are_enforced():
    client = make_client()
    gif = BytesIO()
    Image.new("RGB", (2, 2), color="white").save(gif, format="GIF")
    unsupported = client.post(
        "/api/v1/inference/outside-hive",
        files={"image": ("image.gif", gif.getvalue(), "image/gif")},
    )
    oversized = client.post(
        "/api/v1/inference/outside-hive",
        files={"image": ("large.jpg", b"0" * (10 * 1024 * 1024 + 1), "image/jpeg")},
    )
    assert unsupported.status_code == 415
    assert oversized.status_code == 413


def test_authentication_is_required():
    client = make_client(authenticated=False)
    response = client.post(
        "/api/v1/inference/outside-hive",
        files={"image": ("outside.png", image_upload(), "image/png")},
    )
    assert response.status_code == 401
