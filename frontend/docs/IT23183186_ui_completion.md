# Colony UI completion

Open Environment, select an apiary and hive, and choose Colony workspace. The same workspace is reachable from Hive environment. Child pages retain back navigation and the main Environment bottom-navigation destination stays unchanged.

The workspace has seven sections:

| Section | Available flow |
| --- | --- |
| Overview | Current assessment, evidence availability, latest hive readings, model availability, and latest beekeeper observations |
| Observations | Inspection date, queen evidence, food stores, brood pattern, observed flight activity, local forage, brood-frame count, optional population estimate, and notes; save and reload |
| Trends | Actual IoT temperature/humidity/weight history and net recorded changes; manual activity/population observations remain labeled separately |
| Alerts | Current environmental/sensor alerts and saved visual indicators; needs-review/all views, persistent reviews, and follow-up planning |
| Care | Evidence-based management checklist, planned follow-up actions, completion records, and recording expert-advised treatments without app-generated prescriptions |
| Images | Camera/gallery entry, current model integration state, opt-in saving of server-generated findings/combined assessments, and per-hive analysis history |
| Settings | Saved foreground-refresh switch/interval, in-app summary preference, and explicit disconnected background-notification state |

New screens are IT23183186_colony_workspace_screen.dart, IT23183186_colony_observation_screen.dart, and IT23183186_care_plan_screen.dart. Shared presentation is in IT23183186_colony_ui.dart. The UI uses the shared Inter typography and AppColors palette. No runtime packages were added.

## Data and API

Authenticated APIs under `/api/v1/environment/hives/{hiveId}` support workspace loading, observations, care-plans, completion, alert-reviews, and preferences. Every read/write checks hive ownership. Records are scoped under the hive in Firestore collections `IT23183186_observations`, `IT23183186_care_plans`, `IT23183186_alert_reviews`, and `IT23183186_workspace` (preferences document). Image results use the existing `IT23183186_environment_history` collection with record_type `image_assessment`.

The image analyze endpoint accepts save_result=true when a hive is selected. It saves backend-produced outputs, source context, and the combined preliminary assessment; it does not trust a client-provided prediction. Image storage is analysis-only: original photo files are not retained. Failed history writes preserve the inference response and show a save-failure message.

Observation forms reject empty inspections, future dates, negative/invalid counts, and brood counts larger than the saved hive frame count. Expert-directed treatment records require an adviser and procedure; the app does not choose drugs or doses. Alert reviews are tied to evidence fingerprints so a new observation can produce a new review item.

## UI readiness versus research/service readiness

All planned interaction flows above have implemented screens, states and authenticated persistence. This does not mean every research model, hardware input, or external delivery service is ready:

- The environmental/disease assessment is still a preliminary rules baseline, not a validated environmental-correlation model or calibrated disease probability.
- Actual sensor values require the IoT feed. The current IoT contract provides temperature, humidity and weight; a bee-activity sensor contract is not connected.
- Weight changes are descriptive trends; no validated weight/activity anomaly classifier is claimed.
- Background push notifications and photo-file cloud storage are not connected. Their states are disclosed in the UI.
- Image inference requires valid trained checkpoints. Model B is structural detection and does not diagnose brood disease.
- Care plans record management follow-up and expert instructions; treatment recommendations still need expert-reviewed content and local product-label validation.

These dependencies are shown as unavailable or inconclusive when appropriate. No sample readings are represented as real colony data.

Restart FastAPI and hot-restart Flutter after updating. Live saving requires the existing signed-in session and Firebase configuration. Tests use data fixtures and an in-memory database double; they do not create production records.
