
import csv
from pathlib import Path

import joblib
import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

DATASET = Path(r"E:\MSPB_Dataset")
OUTPUT = Path(__file__).parent

# Keep the previous trained model safe
MODEL_PATH = OUTPUT / "colony_sensor_anomaly_model_v2.joblib"

rng = np.random.default_rng(42)

# Random samples from across BOTH CSV files
SAMPLES_PER_FILE = 25000
features = []

for filename in [
    "D1_sensor_data.csv",
    "D2_sensor_data.csv"
]:
    path = DATASET / filename
    samples = []
    valid_count = 0

    print("\nReading:", filename)

    with path.open(
        "r", encoding="utf-8-sig", newline=""
    ) as f:
        reader = csv.DictReader(f)

        for row in reader:
            try:
                temp = float(row["temperature"])
                humidity = float(row["humidity"])

                if not (
                    np.isfinite(temp)
                    and np.isfinite(humidity)
                    and -20 <= temp <= 60
                    and 0 <= humidity <= 100
                ):
                    continue

            except (ValueError, TypeError):
                continue

            valid_count += 1
            value = [temp, humidity]

            # Reservoir sampling
            if len(samples) < SAMPLES_PER_FILE:
                samples.append(value)
            else:
                index = rng.integers(0, valid_count)

                if index < SAMPLES_PER_FILE:
                    samples[index] = value

    print("Valid readings:", valid_count)
    print("Selected samples:", len(samples))

    features.extend(samples)

X = np.asarray(features, dtype=float)

if len(X) < 100:
    raise ValueError("Not enough valid sensor data")

print("\nTotal training samples:", len(X))

model = make_pipeline(
    StandardScaler(),
    IsolationForest(
        n_estimators=200,
        contamination=0.05,
        random_state=42,
        n_jobs=1
    )
)

model.fit(X)

predictions = model.predict(X)

print("\nTRAINING COMPLETED")
print("Normal patterns:", int(np.sum(predictions == 1)))
print("Anomalies:", int(np.sum(predictions == -1)))

# Compare a few inputs
test_values = np.array([
    [20, 40],
    [25, 60],
    [30.1, 76.6],
    [35, 80]
], dtype=float)

print("\nTEST PREDICTIONS")

for values, prediction in zip(
    test_values,
    model.predict(test_values)
):
    result = (
        "Normal Pattern"
        if prediction == 1
        else "Anomalous Pattern"
    )

    print(
        f"Temp={values[0]}, "
        f"Humidity={values[1]} -> {result}"
    )

joblib.dump(model, MODEL_PATH)

print("\nSaved:", MODEL_PATH)
