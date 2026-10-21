
import csv
from pathlib import Path

DATASET = Path(r"E:\MSPB_Dataset")

files = [
    "D1_sensor_data.csv",
    "D2_sensor_data.csv"
]

for filename in files:
    path = DATASET / filename

    print("\n" + "=" * 50)
    print("FILE:", filename)

    if not path.exists():
        print("FILE NOT FOUND:", path)
        continue

    with path.open(
        "r",
        encoding="utf-8-sig",
        errors="replace",
        newline=""
    ) as f:
        sample = f.read(8192)
        f.seek(0)

        try:
            dialect = csv.Sniffer().sniff(
                sample, delimiters=",;\t"
            )
        except csv.Error:
            dialect = csv.excel

        reader = csv.reader(f, dialect)

        print("COLUMNS:")
        print(next(reader, []))

        print("\nFIRST 3 ROWS:")
        for i, row in enumerate(reader):
            if i >= 3:
                break
            print(row)

print("\nInspection completed!")


print("\nSENSOR ID CHECK")

for filename in files:
    path = DATASET / filename
    if not path.exists():
        continue

    sensor_ids = set()
    hubs = set()

    with path.open(
        "r", encoding="utf-8-sig",
        errors="replace", newline=""
    ) as f:
        reader = csv.DictReader(f)

        for i, row in enumerate(reader):
            sensor_ids.add(row["tag_number"])
            hubs.add(row["beehub_name"])

            if i >= 19999:
                break

    print("\nFILE:", filename)
    print("Sensor IDs:", sorted(sensor_ids))
    print("Bee hubs:", sorted(hubs))
    print("Unique sensors in sample:", len(sensor_ids))
