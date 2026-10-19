# Model B dataset access and annotation inspection

## Finding

FAIRHiveFrames-1K's published metadata describes a suitable object-detection dataset: 1,265 1920 x 1080 PNG hive-frame images, 124,669 bounding boxes, YOLO text labels and Pascal VOC XML, and seven structural classes. The classes are `CappedHoneyCell`, `CappedWorkerBroodCell`, `EmptyCombCell`, `PollenCell`, `UncappedNectarCell`, `UncappedWorkerLarvaCell`, and `BeeHiveFrame`. The paper reports a fixed 1,012-image training split and 253-image validation split, with no independent test split. Its license is CC BY 4.0. These labels support comb-structure detection; they are not verified disease labels.

| Class | Published boxes |
|---|---:|
| CappedHoneyCell | 25,422 |
| CappedWorkerBroodCell | 24,966 |
| EmptyCombCell | 23,677 |
| PollenCell | 18,078 |
| UncappedNectarCell | 12,119 |
| UncappedWorkerLarvaCell | 19,142 |
| BeeHiveFrame | 1,265 |

Sources: [FAIRHiveFrames-1K paper](https://www.mdpi.com/1424-8220/26/8/2518), [Zenodo dataset record](https://zenodo.org/records/19241078).

## Local data and access check

The project dataset folder supplied for this work contains the separate `archive.zip` / `bee_data.csv` dataset, but no FAIRHiveFrames archive, image directory, or annotations. The Zenodo record currently contains only its 2.1 kB metadata/readme file; it points to the archive on Utah State University Box. The published Box static ZIP URL returned HTTP 404 during this inspection. I did not substitute another dataset or train on the paper's summary statistics.

Because the actual images and labels are unavailable locally, this run could not verify individual annotation/image matches, box coordinates, missing/corrupted files, duplicate captures, or per-class annotation counts from the archive. No preprocessing, YOLO conversion, training, or model evaluation was performed for Model B.

## Split plan once the archive is available

Preserve the supplied train/validation split. Since no official test split exists, form a reproducible group-aware test holdout from the official training portion, keeping related images/sessions together; leave the official validation split for model selection. Validate YOLO class IDs and normalized box bounds before training. Use the seven documented class names exactly. Do not label these structures as AFB, EFB, Chalkbrood, Sacbrood, or other diseases.

To continue Model B, provide a working copy of the official archive or its local path, or an active download link from the dataset maintainers.
