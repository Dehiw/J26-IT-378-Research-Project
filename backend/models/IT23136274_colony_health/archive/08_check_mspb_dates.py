
import csv
from pathlib import Path
from collections import defaultdict

BASE = Path(r"E:\MSPB_Dataset")

for filename in ["D1_sensor_data.csv", "D2_sensor_data.csv"]:
    print("\nFILE:", filename)
    ranges = defaultdict(lambda: [None, None, 0])

    with (BASE / filename).open(
        "r", encoding="utf-8-sig", newline=""
    ) as f:
        reader = csv.DictReader(f)

        for row in reader:
            tag = row["tag_number"].strip()
            date = row["date"].strip()

            if not tag or not date:
                continue

            r = ranges[tag]
            if r[0] is None or date < r[0]:
                r[0] = date
            if r[1] is None or date > r[1]:
                r[1] = date
            r[2] += 1

    print("Total sensors:", len(ranges))
    print("Earliest date:", min(r[0] for r in ranges.values()))
    print("Latest date:", max(r[1] for r in ranges.values()))

    print("\nSAMPLE SENSOR DATE RANGES:")
    for tag, r in list(sorted(ranges.items()))[:10]:
        print(tag, r[0], "to", r[1], "Readings:", r[2])
