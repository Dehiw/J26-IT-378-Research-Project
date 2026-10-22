# Hive environment flow

Environment is the entry point. Select a saved apiary, then a hive fetched through the authenticated ApiaryService endpoints. Weather uses that apiary's GPS coordinates, with its saved location name as fallback. A manual weather location is an explicit temporary override. Hive monitoring and photo checks receive the selected hive ID.

The new `IT23183186_hive_environment_screen.dart` shows the saved hive profile, outdoor conditions, current seasonal context, and colony observations. Outdoor weather is kept separate from hive measurements. Missing providers show an unavailable state; no sensor values or health scores are invented.

Add Hive now has an apiary-location dropdown populated from the existing backend. Saving uses the selected apiary ID, and the Environment dashboard refreshes its hive list after the form returns. Existing backend routes and database schema are reused.

No treatment doses or screenshot sample records were imported. The screenshots informed card shapes, spacing, hierarchy, and the cream/green/gold presentation; the app's shared typography, palette, and bottom navigation remain in use.

Checks: widget tests cover apiary/hive switching, outgoing hive/location context, saving to a selected apiary, 320px and 900px layouts, missing GPS, provider failure, and retry. Tests use fixtures; a signed-in backend and configured WeatherAPI are required for live data.

## Saved snapshots

In Environment, choose an apiary and hive, open Hive environment, then tap Save snapshot. The authenticated backend builds a fresh assessment using the saved apiary location and writes it to `hives/{hiveId}/IT23183186_environment_history/{recordId}` in Firestore. The Save action is explicit; simply viewing current weather does not create records.

Records contain user/hive/apiary IDs, UTC save time, location query/source, available outdoor weather and provider observation time, environmental analysis, sensor evidence, assessment rules/version, alerts, and missing inputs. These snapshots do not include new image inference or uploaded photos. Missing providers remain unavailable in the saved record. Saved history shows the latest 20 records and supports refresh/retry.

API: `POST /api/v1/environment/hives/{hiveId}/records` and `GET /api/v1/environment/hives/{hiveId}/records?limit=20`. Both require the existing bearer token and verify hive ownership; requests to another user's hive return 404. POST optionally accepts `q` as a location override; the UI uses the saved apiary location. The backend computes assessment values itself rather than trusting client-supplied results. No new Firestore composite index is needed (history is ordered by one field inside the hive subcollection).

Restart the FastAPI backend and hot-restart Flutter after updating. Live persistence requires valid Firebase credentials, a signed-in user, and a reachable backend. WeatherAPI configuration is needed for weather; unavailable weather can still be recorded as missing evidence. Automated tests use an in-memory Firestore double and API fixtures; no production records are created by tests.
