# Model B: YOLO11n hive-frame detector

This is the model definition and run tooling for the seven structural FAIRHiveFrames-1K labels. The classes identify comb and frame structures; they are not disease labels. No model was trained because the local project copy does not contain the dataset archive or annotations. See [INSPECTION_REPORT.md](INSPECTION_REPORT.md) for the source, license, published counts, and dataset access finding.

The official release has train and validation splits, but no independent test split. Before training, preserve those official splits and create a reproducible, group-aware test holdout from the official training data. Validate that original YOLO boxes and image/label matches are sound. The training script checks configured split paths and exact class names, but does not replace that data audit.

## Model and commands

The architecture entry point is `model.py`; `train.py` fine-tunes pretrained `yolo11n.pt` at image size 640 by default. Ultralytics documents `YOLO("yolo11n.pt")` followed by `model.train(data=..., epochs=..., imgsz=640)` for this workflow ([YOLO11 documentation](https://docs.ultralytics.com/models/yolo11/)).

From the repository root, set up an isolated Python 3.11 environment:

```powershell
py -3.11 -m venv backend\ml\model_b_hive_frame_detector\.venv
backend\ml\model_b_hive_frame_detector\.venv\Scripts\python.exe -m pip install --upgrade pip
backend\ml\model_b_hive_frame_detector\.venv\Scripts\python.exe -m pip install -r backend\ml\model_b_hive_frame_detector\requirements.txt
```

After obtaining, inspecting, and preparing the dataset, copy `dataset.yaml.example` to a real `dataset.yaml`, update its paths, and point its `names` at the verified seven classes. The `test` path should point to the group-aware holdout; do not use the official validation split as the final test set.

```powershell
$python = 'backend\ml\model_b_hive_frame_detector\.venv\Scripts\python.exe'
$data = 'C:\datasets\FAIRHiveFrames_prepared\dataset.yaml'
& $python backend\ml\model_b_hive_frame_detector\train.py --data $data --epochs 100 --imgsz 640 --batch 8 --patience 20
```

Ultralytics saves `best.pt`, training logs, and plots under `backend\ml\model_b_hive_frame_detector\runs\fairhive_yolo11n` by default. Then evaluate the untouched test split:

```powershell
$best = 'backend\ml\model_b_hive_frame_detector\runs\fairhive_yolo11n\weights\best.pt'
& $python backend\ml\model_b_hive_frame_detector\evaluate.py --data $data --weights $best --imgsz 640 --batch 8
```

The evaluation command writes `test_evaluation.json` and Ultralytics validation plots/metrics. Report measured precision, recall, mAP50, mAP50-95, per-class output, and the confusion matrix produced by the validation run. Do not describe these structural detections as AFB, EFB, Chalkbrood, Sacbrood, or another disease.

## Device and memory

The requirements file creates a CPU-only PyTorch setup matching Model A. For CUDA, create a fresh environment, install the PyTorch build that matches the target machine from the official PyTorch installer, then install `ultralytics>=8.3,<9` and `PyYAML>=6,<7` without reinstalling PyTorch. Ultralytics accepts `--device 0` for a CUDA GPU and `--device cpu` for CPU; 640-pixel training on CPU will take substantially longer. Windows multiprocessing is protected by the `if __name__ == "__main__"` entry point.
