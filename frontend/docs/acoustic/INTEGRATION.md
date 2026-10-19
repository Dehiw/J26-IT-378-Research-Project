# Acoustic module: integration notes

The Acoustic module (Hive Sound Monitor, Recording, Result, Sound History) is
merged into the main app. Its files sit in an `acoustic` sub-folder of each
team folder under `frontend/lib`, and the tests mirror them under
`frontend/test`.

## Where things are

| Kind | Path |
| --- | --- |
| Entry point (`openSoundMonitor`, hive provider, nav bar wiring) | `lib/screens/acoustic/acoustic_entry.dart` |
| Screens and flows | `lib/screens/acoustic/` |
| Services (mock service, recorder, WAV, upload) | `lib/services/acoustic/` |
| Models | `lib/models/acoustic/` |
| Widgets | `lib/widgets/acoustic/` |
| Config, strings, formatting | `lib/utils/acoustic/` |
| Dev-only preview (`acoustic_demo_main.dart`, `wav_debug_saver.dart`) | `lib/acoustic/dev/` |
| Tests | `test/screens/acoustic/`, `test/services/acoustic/`, `test/models/acoustic/` |
| Test fakes | `test/support/acoustic/` |

Run the dev preview on its own with
`flutter run -t lib/acoustic/dev/acoustic_demo_main.dart`.

## How the app reaches the Monitor

- `lib/screens/home_screen.dart`, `_onNavTapped`, index 3 (Acoustic) calls
  `openSoundMonitor(context, inferenceService: widget.inferenceService)`.
- The Monitor shows the shared `MainBottomNav` (`lib/widgets/main_bottom_nav.dart`)
  with Acoustic selected. Home pops back to Home, Health, Relocate and
  Environment are pushed the same way the team's screens do it. Recording,
  Result and History are full-screen and have no bar.
- The hive list comes from `ApiaryService` through `apiaryHivesProvider`. A
  user with no apiary sees an empty list. Results are still made up (the demo
  notice stays on) and history is in memory only, until the backend has
  acoustic endpoints.

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
