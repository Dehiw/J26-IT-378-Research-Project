# Acoustic module: integration steps

This file lists the changes outside `lib/acoustic` that connect the Acoustic
module to the main app. Apply them in step B, after step A is merged.

Step A (inside `lib/acoustic` and `test/acoustic` only) is already done:

- `acoustic_entry.dart` has `openSoundMonitor(context, {hiveId})` and the one
  line that creates the service.
- The demo notice shows while the service reports `isDemo` (the mock does).
- Hive names come from `HiveOption.name`, through `HiveNames`.

## Before you start

1. Merge `origin/main` into the branch first. Step B depends on
   `ApiaryService`, `ApiaryModel` and `HiveModel`, which exist only on
   `origin/main`.
2. Run `flutter pub get` after the `pubspec.yaml` change.

## B1. `frontend/lib/screens/home_screen.dart`: Acoustic tab

Add the import next to the other imports:

```diff
 import '../services/apiary_service.dart';
+import '../acoustic/acoustic_entry.dart';
```

Replace the snackbar that the Acoustic tab currently shows. In
`_onNavTapped`, the final `else` is reached only for index 3, because
indices 0, 1, 2 and 4 are handled above it:

```diff
     } else {
-      ScaffoldMessenger.of(context).showSnackBar(
-        SnackBar(
-          content: Text(
-            'Acoustic monitoring is coming soon.',
-            style: GoogleFonts.inter(color: AppColors.bgSecondary),
-          ),
-          backgroundColor: AppColors.panelBlack,
-          behavior: SnackBarBehavior.floating,
-        ),
-      );
+      openSoundMonitor(context).then((_) {
+        if (mounted) setState(() => _currentIndex = 0);
+      });
     }
```

`GoogleFonts` is still used elsewhere in the file, so its import stays.

## B2. `frontend/lib/acoustic/acoustic_entry.dart`: hive list from the app

Uncomment the imports and the `apiaryHivesProvider` block at the bottom of
the file, then pass the provider to the mock:

```diff
-AcousticService acousticService = MockAcousticService(
-  // Step B: hivesProvider: apiaryHivesProvider,
-);
+AcousticService acousticService = MockAcousticService(
+  hivesProvider: apiaryHivesProvider,
+);
```

With this, the Monitor lists the user's real hives. A user with no apiary
sees an empty list. Results are still made up (the notice stays on), and
history is in memory only, until the backend has acoustic endpoints.

## B3. `frontend/pubspec.yaml`

Under `dependencies:`, after `lottie: ^3.1.2`:

```diff
   lottie: ^3.1.2
+  record: ^7.1.2
+  file_picker: ^13.1.0
```

## B4. `frontend/android/app/src/main/AndroidManifest.xml`

After the CAMERA permission:

```diff
     <uses-permission android:name="android.permission.CAMERA"/>
+    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

Android's default `minSdk` for this Flutter SDK is 24, which `record` supports.

## B5. `frontend/ios/Runner/Info.plist`

iOS requires a usage description before the app can ask for the microphone.
Add these two lines inside the top-level `<dict>`, for example just before
`</dict>` at the end of the file:

```diff
+	<key>NSMicrophoneUsageDescription</key>
+	<string>Hive Sense uses the microphone to record hive sound for analysis.</string>
```

## Not part of this integration

- Do not commit `frontend/.metadata`. It is a Flutter tool file that shows
  as modified.
- The `_navigate` switch in the IT23183186 screens maps index 3 to Hive
  Telemetry. Agree the meaning of the Acoustic tab with that owner before
  changing it. Step B does not touch those files.

## After step B

- `flutter analyze` and `flutter test` pass.
- Run on a device: check the microphone prompt, a recording, an upload, and
  the Acoustic tab opening the Monitor with the user's hives.
