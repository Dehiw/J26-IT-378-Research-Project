# Acoustic module: integration notes

The Acoustic module (Hive Sound Monitor, Recording, Result, Sound History) is
merged into the main app. Its files follow the team's flat layout: they sit
directly in `frontend/lib/{screens,services,models,widgets,utils}` with the
prefix `IT23139930_`, and the tests mirror them under `frontend/test`.

## Where things are

| Kind | Path |
| --- | --- |
| Entry point (`openSoundMonitor`, hive provider, nav bar wiring) | `lib/screens/IT23139930_acoustic_entry.dart` |
| Screens and flows | `lib/screens/IT23139930_*.dart` |
| Services (HTTP and mock service, recorder, WAV, upload) | `lib/services/IT23139930_*.dart` |
| Models | `lib/models/IT23139930_*.dart` |
| Widgets | `lib/widgets/IT23139930_*.dart` |
| Config, strings, formatting | `lib/utils/IT23139930_*.dart` |
| Tests | `test/screens/`, `test/services/`, `test/models/` (`IT23139930_*_test.dart`) |
| Test fakes | `test/support/IT23139930_*.dart` |

The module runs inside the main app. There is no separate dev entry point.
`AcousticConfig.useRealModel` (in `lib/utils/IT23139930_acoustic_config.dart`)
chooses the backend model (true) or the mock (false).

## How the app reaches the Monitor

- `lib/screens/home_screen.dart`, `_onNavTapped`, index 3 (Acoustic) calls
  `openSoundMonitor(context, inferenceService: widget.inferenceService)`.
- The Monitor shows the shared `MainBottomNav` (`lib/widgets/main_bottom_nav.dart`)
  with Acoustic selected. Home pops back to Home, Health, Relocate and
  Environment are pushed the same way the team's screens do it. Recording,
  Result and History are full-screen and have no bar.
- The hive list comes from `ApiaryService` through `apiaryHivesProvider`. A
  user with no apiary sees an empty list. With `useRealModel = true` results
  come from the backend model (`/api/v1/acoustic`, run with
  `uvicorn app.main:app --reload`); with false they are made up and
  history is in memory only.

## Shared changes made for the module

- `pubspec.yaml`: `record: ^7.1.2`, `file_picker: ^13.1.0`.
- `android/app/src/main/AndroidManifest.xml`: `RECORD_AUDIO`.
- `ios/Runner/Info.plist`: `NSMicrophoneUsageDescription`.

## Open points

- Other screens' bottom bars send index 3 to `ScannerScreen`, not to the
  Acoustic tab: `health_screen`, `hive_health_dashboard_screen` and the
  `it23136274_*` screens. Their owners decide whether to change that. The
  `normal_user_home_screen` and the IT23185302 normal-user screens map index 3
  to the beekeepers directory, which is a different bar.
- Do not commit `frontend/.metadata`. It is a Flutter tool file.
