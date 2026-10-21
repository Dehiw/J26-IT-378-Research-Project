
import csv
from pathlib import Path

import joblib
import numpy as np

BASE = Path(__file__).parent
DATASET = Path(r"E:\MSPB_Dataset")

model = joblib.load(
    BASE / "colony_sensor_anomaly_model_v2.joblib"
)

# Use D2 readings as a separate behavioral check.
# D2 was also used during training, so this is NOT
# an independent accuracy evaluation.
FILE = DATASET / "D2_sensor_data.csv"

samples = []
sensor_ids = set()

with FILE.open("r", encoding="utf-8-sig", newline="") as f:
    reader = csv.DictReader(f)

    # Select every 100th valid row to cover more of the file.
    valid_index = 0

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

        if valid_index % 100 == 0:
            samples.append([temp, humidity])
            sensor_ids.add(row["tag_number"])

        valid_index += 1

X = np.asarray(samples, dtype=float)

predictions = model.predict(X)

normal = int(np.sum(predictions == 1))
anomalies = int(np.sum(predictions == -1))

print("\n=== MODEL VALIDATION CHECK ===")
print("Model: Isolation Forest V2")
print("Dataset: MSPB D2")
print("Readings checked:", len(X))
print("Sensor IDs represented:", len(sensor_ids))
print("Normal patterns:", normal)
print("Anomalous patterns:", anomalies)
print("Anomaly percentage:", round(
    anomalies / len(X) * 100, 2
), "%")

print("\nNOTE:")
print("This measures model behavior, NOT health accuracy.")
print("No verified anomaly labels were used.")
