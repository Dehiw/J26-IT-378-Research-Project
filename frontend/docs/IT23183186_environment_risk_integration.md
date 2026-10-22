# IT23183186 environment, images and colony monitoring

## Dashboard refresh and weather error check — 2026-10-20

The Environment dashboard now follows the shared Skills palette and Inter typography with a centered 1120px content limit, responsive one/two-column sections, a compact expandable monitoring summary, dedicated weather metrics and a clear weather-connection failure state. The garbled greeting was removed. Bottom navigation remains visible with Environment selected, and no external component shortcuts were added.

A direct request using the configured backend `.env` key returned WeatherAPI HTTP 401 / error 2006 (invalid key); no current weather was returned. The key was neither printed nor changed. Replace `WEATHERAPI_KEY` in `backend/.env` with a valid WeatherAPI account key, then fully restart Uvicorn. The backend now maps invalid/missing/disabled provider credentials to a sanitized 503 configuration error rather than forwarding a misleading user-authentication 401. Account quota/history-access failures also receive a clear 503 message. Inconclusive monitoring is expected when usable weather, sensor or image evidence is missing.

Checks after the refresh: 19 backend tests passed, four selected Flutter tests passed (including a narrow-screen compact-card layout check), and static analysis of the changed dashboard/card passed. The live weather check above failed due to the configured key, so successful live-weather rendering is not claimed.

Implemented and checked on 2026-10-20. This is a preliminary rules-based monitoring flow, not a trained environmental-correlation model or a validated disease classifier.

## User flow

Navigation requirement: the shared bottom navigation's **Environment** tab is the only external entry to IT23183186's component. The Environment dashboard also displays the shared bottom bar with Environment selected, allowing navigation to Home, Health, Relocate and Acoustic. Its dashboard opens the component's risk, upload, telemetry and forage pages. Do not add component shortcuts, cards or buttons to Home, Health, Relocate, Acoustic or other members' pages. Existing Environment-tab handlers on those pages remain valid; child component pages keep back navigation.

Environment dashboard uses saved apiary GPS, device GPS, or the existing location fallback. It shows current outdoor WeatherAPI observations, the previous seven days where the provider subscription permits, Sri Lankan calendar-season context, observed rainfall summaries and current monitoring alerts. A seven-day window is not a seasonal climate trend. Population, colony growth and food stores are not inferred from weather.

Disease check / Risk overview opens the authenticated colony monitoring page. Choose a hive to read its actual latest sensor record. The backend verifies that the hive belongs to the signed-in user before querying its readings. The telemetry page uses this same canonical flow instead of sample charts. Select the hive's actual location for the weather query.

Upload hive images opens the existing FastAPI upload flow, with independent individual-bee and inside-frame photos, previews and separate outputs. From monitoring, the selected location/hive is passed to this flow. Results include environmental alerts and any supported visual indicator. Missing checkpoints remain unavailable. Image findings are held only for the current upload request; returning to monitoring does not imply a persisted image assessment.

Alerts appear in the app on load/refresh. They are stable rule IDs within each response, not stored alert history, background monitoring, local OS notifications or push notifications. Those require a separate scheduler/delivery implementation.

## API contract

- Existing `GET /api/v1/environment/weather`, `/impact`, and `/weather/history` remain compatible. Current weather adds `last_updated_epoch`; history adds an `analysis` summary.
- New authenticated `GET /api/v1/environment/assessment?q=<location>&hive_id=<optional hive>` returns `assessment`, `weather`, `environment`, `sensor` and `weather_error`.
- Existing authenticated `POST /api/v1/inference/analyze` accepts the same optional `outside_image` and `inside_image` multipart fields, plus optional `q` and `hive_id`. At least one image is required. It returns separate model outputs and a shared `assessment`.
- Weather outages and missing sensor readings produce partial/inconclusive evidence. Unowned/unknown hives return 404. Corrupt or oversized images retain existing 415/413 behavior.
- Sensor fields reuse the existing contract: `temperature` (C), `humidity` (%), `weight` (kg), `timestamp` (ISO timestamp). The existing ingestion endpoint timestamps receipt; freshness does not independently verify the physical capture time or sensor calibration.

## Monitoring rules, version IT23183186-monitoring-v1

These numerical bands are **unvalidated research defaults chosen for operational review**, not thresholds established by the linked background sources. Review them with local bee-health experts for bee species, sensor placement and local climate before operational deployment. Values are centralized in `backend/app/services/IT23183186_colony_assessment.py` under `RULES`.

| Input | Trigger | Output |
| --- | --- | --- |
| Fresh outdoor temperature | <=15 C or >=35 C | Warning |
| Fresh outdoor temperature | <=10 C or >=40 C | High environmental monitoring alert |
| Fresh outdoor humidity | >=85% | Moisture/ventilation inspection warning; no hive humidity inferred |
| Fresh current precipitation | >0 mm | Potential interruption of foraging; not a daily rainfall total |
| Fresh hive temperature | <30 C or >38 C | Verify sensor placement and inspect hive |
| Fresh hive humidity | <40% or >85% | Verify sensor placement and inspect hive |
| Supported Model A result | `varroa_positive` | Elevated visual indicator requiring direct inspection |
| Model B detections | Any structural class | Context only; no disease rule |

Weather older than 120 minutes and sensors older than 60 minutes do not trigger numeric monitoring rules. Missing/invalid/naive timestamps are not fresh; up to five minutes of future clock skew is tolerated. Alerts from weather/sensors never establish disease. A healthy bee crop or absence of alerts never establishes a healthy colony. No disease probability or numeric disease-risk score is generated.

Background references: [Sri Lankan rainfall seasons](https://www.statistics.gov.lk/abstract2024/chapter1), [seasonal bee management](https://extension.psu.edu/honey-bee-management-throughout-the-seasons). The regional coordinate estimate remains approximate. These references do not validate the research monitoring bands.

## Changed implementation files

Backend:

- `app/services/IT23183186_colony_assessment.py`: evidence freshness, monitoring rules, alerts and limitations.
- `app/services/IT23183186_environmental_impact.py`: observed history summary, population/development uncertainty, Colombo calendar fallback.
- `app/routes/IT23183186_environment.py`: authenticated assessment, owned-hive telemetry, weather epoch, provider response checks, history summary and Sri Lankan date boundary.
- `app/routes/IT23183186_image_inference.py`: optional location/hive fields and shared assessment.
- `app/services/IT23183186_image_model_service.py`: corrected model directory defaults. Set checkpoint environment variables for artifacts inside named run directories.
- `tests/test_image_inference.py`, `tests/test_IT23183186_colony_assessment.py`: route and rule checks.
- `tests/IT23183186_smoke_server.py`: loopback-only contract fixture with explicitly unavailable models; never run as the production API.

Flutter:

- `lib/services/IT23183186_colony_assessment_api.dart`: authenticated assessment client.
- `lib/services/image_inference_api.dart`: location/hive multipart fields.
- `lib/services/weather_service.dart`: population/development fields and historical summary parsing; existing `fetchHistory` remains available.
- `lib/widgets/IT23183186_assessment_card.dart`: shared alert/evidence/rules card.
- `lib/screens/IT23183186_environment_dashboard_screen.dart`: monitoring alerts, history interpretation and updated navigation/context.
- `lib/screens/IT23183186_disease_risk_screen.dart`: live monitoring, hive selection and real latest readings.
- `lib/screens/IT23183186_disease_check_screen.dart`, `IT23183186_disease_assessment_screen.dart`, `IT23183186_hive_telemetry_screen.dart`: retain existing public screen classes and direct them to the canonical connected flows.
- `lib/screens/image_model_analysis_screen.dart`: shared assessment, location/hive context and prevention of photo changes during a request.
- `test/image_inference_api_test.dart`, `test/IT23183186_assessment_card_test.dart`, `test/image_inference_live_api_test.dart`: multipart, alert UI and live HTTP checks.

## Verification actually executed

From the repository root, using the installed system Python 3.13 environment:

```powershell
python -B -m pytest -p no:cacheprovider backend/tests/test_image_inference.py backend/tests/test_IT23183186_colony_assessment.py -q
git diff --check
```

Result: **18 passed**; one existing Starlette/httpx deprecation warning. Diff whitespace check passed. The backend `.venv` still lacks the image dependencies/pytest reported during inspection; these results do not claim that environment is ready.

From `frontend`:

```powershell
flutter analyze --no-pub lib/screens/IT23183186_disease_risk_screen.dart lib/screens/IT23183186_disease_check_screen.dart lib/screens/IT23183186_disease_assessment_screen.dart lib/screens/IT23183186_hive_telemetry_screen.dart lib/screens/image_model_analysis_screen.dart lib/screens/IT23183186_environment_dashboard_screen.dart lib/services/IT23183186_colony_assessment_api.dart lib/services/image_inference_api.dart lib/services/weather_service.dart lib/widgets/IT23183186_assessment_card.dart
```

Result: **No issues found**. Changed Dart files were formatted with the installed Dart formatter.

For the live HTTP contract test, start the isolated fixture from `backend` using system Python:

```powershell
python -B tests/IT23183186_smoke_server.py
```

Then from `frontend`:

```powershell
flutter test --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:8765/api/v1 --dart-define=HIVE_SENSE_TEST_TOKEN=integration-test-only test/image_inference_api_test.dart test/IT23183186_assessment_card_test.dart test/image_inference_live_api_test.dart
```

Result: **4 passed**. Flutter sent both photos to the loopback FastAPI fixture and received HTTP 200, separate unavailable model statuses, and an inconclusive assessment. The fixture was stopped afterward. This verifies real multipart HTTP transport and unavailable-model behavior, not production authentication, WeatherAPI credentials/subscription, Firebase hardware readings, trained checkpoints or model accuracy. No live production account/provider data was used.

## Remaining deployment/research work

Install consistent backend dependency pins (the existing requirements files disagree on NumPy), configure WeatherAPI and Firebase, install and evaluate both trained model checkpoints, validate monitoring thresholds, and verify the flow using actual hive hardware and field images. No training, checkpoint download, disease-model accuracy claim or push-notification delivery was performed in this change.
