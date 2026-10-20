# Live demo: real queen-status result in the app

The app sends a WAV file to the backend. The backend runs the ONNX Random
Forest model and returns **Queen Present** or **Queenless**. Nothing is faked when the model is used.

## Before you start

- `ml/acoustic/models/queen_baseline.onnx` exists (it is git-ignored, 27 MB).
- You can log in, and the account has at least one hive (the app's hive
  selector shows it).
- `frontend/lib/utils/acoustic/acoustic_config.dart` has `useRealModel = true`.

## Steps

1. **Start the backend** (PowerShell, from the repo root):

   ```powershell
   cd backend
   .\venv\Scripts\python.exe -m uvicorn app.acoustic_main:app --reload
   ```

   Check `http://127.0.0.1:8000/api/v1/acoustic/model-info` in a browser. It
   must show `"model_loaded": true`.

2. **Run the app** (second terminal):

   ```powershell
   cd frontend
   flutter run -d windows
   ```

   On an Android emulator the app reaches the backend at `10.0.2.2:8000`
   automatically. A real phone needs the laptop's IP in `lib/utils/api_config.dart`
   (a teammate-owned file, so change it only for the demo).

3. **Log in**, open the **Acoustic** tab (Hive Sound Monitor), and pick the hive.
   The notice reads *"Experimental AI model, accuracy is limited on new hives"*.

4. **Upload a demo clip**: tap Upload Audio, choose a file from
   `ml/acoustic/demo_clips/` (for example `demo_01.wav`). The *Analyzing hive
   sound* screen shows, then the result.

5. **Show the result**: status, confidence, and the guidance note. Compare with
   `demo_clips/demo_clips.csv`, which lists the true label and the model's
   prediction for each clip. Tap **Save Result** to keep it. It then appears in
   Recent analyses and Sound History.

6. **Optional: record live** with the microphone. This is a phone/laptop
   microphone, which the model was never tested on, so say that the result is
   not reliable.

## The demo clips (be honest about them)

- 8 clips, 2 s each, in `ml/acoustic/demo_clips/`. Regenerate with
  `make_demo_clips.py`.
- They are **not** in the 30,000-clip training sample (`data/manifest.csv`), so
  the model has not seen these exact clips.
- They **do** come from the same 12 hives as the training data, and clips from
  one hive are very similar to each other. On a sample of 180 such clips the
  model scored 94% accuracy. That is the same optimistic level as the random
  80/20 split (94.9%), and **not** what to expect on a new hive.
- The honest figure for an unseen hive is the leave-one-hive-out result: about
  **51% accuracy** (range 34% to 87% by hive). See `README.md`.
- The set includes **two clips the model gets wrong** (`correct = NO` in the
  CSV). Use them to show that the model is not perfect.
- Phone recordings were never part of any test, so live-recording accuracy is
  unknown.

## If something goes wrong

| Screen message | Cause |
|---|---|
| Cannot reach the server. Check that the backend is running. | Backend not started, or wrong URL |
| Acoustic model not available | `queen_baseline.onnx` missing, or the audio libraries are not installed |
| Recording is too short | Audio under 2 s |
| Your session has expired. Please log in again. | Token expired |

## Running on another laptop

1. Copy `queen_baseline.onnx` into `ml/acoustic/models/` (it is not in git).
   Or set `ACOUSTIC_MODEL_PATH` to wherever the file is.
2. Install the extra packages into the backend venv:

   ```powershell
   cd backend
   .\venv\Scripts\python.exe -m pip install -r requirements.txt
   .\venv\Scripts\python.exe -m pip install -r requirements-acoustic.txt
   ```

   (`requirements.txt` first on a fresh machine, then the acoustic extras.)
3. Make sure `backend/firebase-service-account.json` is in place (not in git).
4. Start with `.\venv\Scripts\python.exe -m uvicorn app.acoustic_main:app --reload`.

Without the model file the backend still starts, and the app shows
"Acoustic model not available".

## Tests

```powershell
cd backend
.\venv\Scripts\python.exe -m pytest tests -v -s
```

`test_acoustic_parity.py` checks that the backend's 168 features equal
`ml/acoustic/features.py`, and that its predictions equal `predict.py`.
