
from pathlib import Path
import joblib
import numpy as np

BASE = Path(__file__).parent

model = joblib.load(
   BASE / "colony_sensor_anomaly_model_v2.joblib"
)

print("MODEL LOADED SUCCESSFULLY")

while True:
    temp = input("\nTemperature (or q to quit): ")

    if temp.lower() == "q":
        break

    humidity = input("Humidity: ")

    try:
        temperature = float(temp)
        humidity = float(humidity)

        if not (-20 <= temperature <= 60):
            print("Invalid temperature")
            continue

        if not (0 <= humidity <= 100):
            print("Invalid humidity")
            continue

        prediction = model.predict(
            np.array([[temperature, humidity]])
        )[0]

        if prediction == 1:
            print("Result: NORMAL SENSOR PATTERN")
        else:
            print("Result: ANOMALOUS SENSOR PATTERN")
            print("Recommendation: Inspect sensor and hive conditions")

    except ValueError:
        print("Please enter valid numbers")
