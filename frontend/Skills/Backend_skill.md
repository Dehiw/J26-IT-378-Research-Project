# Hive Sense Backend Skill Guide

**For all four research group members.** Read this guide before adding or changing backend code. The goal is for each member's work to be identifiable while the backend remains one integrated FastAPI application.

## 1. Current backend layout

```text
backend/
  app/
    main.py                         # shared FastAPI entry point
    core/security.py                # shared authentication helpers
    firebase/                       # shared Firebase connection
    routes/                         # HTTP API endpoints
    schemas/                        # shared request/response data definitions
    services/                       # reusable application logic
  models/
    IT23183186_model_a_varroa_classifier/
    IT23183186_model_b_hive_frame_detector/
  tests/                            # backend tests
  requirements.txt                  # shared backend dependencies
  .env                              # local secrets/settings; never commit
```

The `backend/app` package is the running API. `backend/models` contains research and training workflows; it is separate from the code that serves HTTP requests. Keep original datasets and generated checkpoints out of source code unless the team explicitly chooses a tracked artifact policy.

## 2. Shared files and member-owned files

Keep integration points shared and unprefixed:

- `app/main.py`: creates the app, loads startup services, and registers routers.
- `app/core/security.py`, `app/firebase/`, and shared configuration.
- `app/schemas/` when a schema is used across routes or members.
- `app/routes/` when a route is part of the public API contract.
- `requirements.txt` and shared test setup.

Prefix member-owned files with the member ID, for example `M1_foraging_service.py`, `M2_sensor_routes.py`, or `M4_image_model_service.py`. Use the assigned member number consistently. Keep conventional filenames such as `train.py`, `evaluate.py`, and `model.py` inside a clearly member-prefixed model directory when that makes research commands and notebook imports easier to follow.

Current M4-owned work includes environmental impact analysis and the two image model pipelines (MobileNetV2 Model A and YOLO11n Model B). Model B describes verified comb/frame structures; do not label those detections as disease findings. Do not assign existing modules to M1–M3 until the group confirms their ownership.

Avoid duplicate implementations. Before creating a service or route, search for an existing implementation and extend it when appropriate. Do not make a second copy with a member prefix just to mark ownership; use a prefixed module or filename for genuinely member-specific logic, while shared entry points remain shared.

## 3. Request flow

```text
Flutter client
    -> app/main.py
    -> app/routes/<feature>.py
    -> app/core/security.py (for authenticated routes)
    -> app/services/ or a member-owned service
    -> Firebase, external provider, or model
    -> API response
```

- **Routes** parse and validate HTTP input, call services, and return stable responses. Keep business logic out of route handlers where it can live in a service.
- **Schemas** define and validate request and response structures. Reuse a shared schema if multiple parts of the app depend on the same contract.
- **Services** perform work such as database operations, environmental calculations, and model inference.
- **`main.py`** is the composition point: it registers the existing routers and initializes long-lived services. Do not create a second FastAPI app for a member module.

The current shared route files include `auth.py`, `apiary.py`, `wild_bee_report.py`, `environment.py`, and `image_inference.py`. Keep their public paths and response formats stable unless the team agrees to an API change and updates Flutter and tests together.

## 4. M4 image model conventions

- Model A classifies supported individual-bee images. It is not intended for whole-hive frames.
- Model B detects supported frame/comb structures only when the dataset annotations are verified as valid for detection.
- Keep each model's training, preprocessing, and evaluation code in its own model directory. Record class names and preprocessing alongside trained artifacts.
- The API service should load each available model once at application startup, validate the expected class mapping, and return a clear unavailable status if a completed checkpoint is missing.
- Validate uploaded image type, size, and readability. Return model outputs separately and include limitations; model confidence is not a disease probability or confirmed diagnosis.
- Do not invent labels or use Model B structural labels as disease labels. Do not claim a model is trained or available without a valid checkpoint and required metadata.

## 5. Imports and file moves

- Use imports rooted at `app`, consistent with the existing backend, for example `from app.services.example_service import run_example`.
- Keep one canonical implementation. If a member module is moved, update all imports, scripts, notebooks, documentation, and tests that reference its old path.
- Treat `main.py`, route paths, authentication dependencies, shared schemas, and Flutter-facing response fields as compatibility-sensitive.
- Check `git status` before moving or editing files. Preserve existing user changes and generated reports; do not replace a modified file with a clean copy.
- Do not rename every file automatically. Prefix only member-owned code where a prefix clarifies ownership.

## 6. Configuration and secrets

- Read credentials and environment-specific settings from environment variables or the local `backend/.env` file.
- Never commit `.env`, Firebase service-account credentials, API keys, or tokens. Do not log secret values or expose internal filesystem paths in API responses.
- Keep shared dependency declarations in `backend/requirements.txt`. Put optional, model-specific dependencies in the relevant model requirements file when practical, and document installation commands.

## 7. Tests and change checklist

Add or update tests for changed route behavior, validation, service outcomes, and error cases. Run the relevant backend tests and report the command and actual result. For changes that affect Flutter-facing behavior, verify that the API path, authentication, multipart field names, and response shape still match the Flutter client.

Before handing off a backend change:

- [ ] Shared entry points and API contracts remain compatible, or coordinated changes are documented.
- [ ] Member ownership is clear without duplicating shared code.
- [ ] Imports, notebook commands, README links, and tests use the correct paths.
- [ ] Secrets and local datasets/checkpoints are not accidentally committed.
- [ ] Dataset or model claims match verified labels and actual saved artifacts.
- [ ] Tests run successfully, or failures and unrun checks are reported accurately.
