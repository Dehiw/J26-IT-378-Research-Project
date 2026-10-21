# Model B notebook dataset setup

`C:/datasets/FAIRHiveFrames_prepared` was an example path, not an installed dataset. A missing folder at that path does not indicate a YOLO or GPU failure.

The local search on 2026-10-20 did not find FAIRHiveFrames in the research `DATAESET` folder, Downloads, or `C:/datasets`. VarroaDataset is a different dataset and must not be used as Model B's data.

1. Locate your FAIRHiveFrames download if it is stored elsewhere. The official dataset record is https://zenodo.org/records/19241078. Preserve the original archive/images/annotations. No download was performed by this fix.
2. Inspect the actual release's image files, YOLO/Pascal VOC bounding boxes, class order and official training/validation manifests. The original release is not necessarily organized as `images/train`, `images/val`, `images/test`; pointing this notebook directly at an unsplit `data/obj` folder is insufficient.
3. Prepare a separate working copy with validated image/label matches and a documented group-aware test holdout. Preserve the official validation set when suitable, and derive the test holdout from training only before model selection. Do not fabricate boxes or disease labels.
4. In the notebook configuration cell, set `PREPARED_DATASET_OVERRIDE` to the actual prepared directory. Alternatively set `HIVESENSE_FAIRHIVE_PREPARED_DIR` before launching Jupyter. Restart/re-run the configuration cell after changing it.

```python
PREPARED_DATASET_OVERRIDE = Path(r'D:/your-actual-data/FAIRHiveFrames_prepared')
```

Replace the example above with an existing path. The conventional structure is:

```text
FAIRHiveFrames_prepared/
  images/train/  images/val/  images/test/
  labels/train/  labels/val/  labels/test/
  dataset.yaml
```

Each label file must contain verified YOLO detection rows: `class_id center_x center_y width height`, with normalized coordinates. A valid existing `dataset.yaml` may reference a different supported directory layout; the notebook preserves it. Class order is fixed in `model.py` and `dataset.yaml.example`.

5. Run the YAML-check cell, then the full dataset-audit cell. Resolve all reported issues before the training cell. Creating empty directories or only a YAML file does not supply a dataset.

This fix validates notebook code syntax and missing-data preflight behavior; it does not claim data preparation, a passing dataset audit, training, or evaluation results.
