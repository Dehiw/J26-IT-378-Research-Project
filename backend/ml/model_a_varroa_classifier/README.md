# Model A: Varroa MobileNetV2 classifier

`model.py` defines the MobileNetV2 network; `train.py` and `evaluate.py` are runnable entry points. Training is intentionally left for you to launch. The currently present `artifacts/best_model.pt` is a partial checkpoint from an interrupted run (head-training epoch 3), not a completed/final model. Rerun the training command below before evaluating; it will create the final metadata and history files.

This pipeline trains a binary classifier on the official VarroaDataset release: `healthy` (raw label 0) and `varroa_positive` (raw labels 1 and 3). The raw global annotation file contains labels 0, 1, and 3; the infected labels 1 and 3 sum to the release's documented 3,947 positive samples. The scripts preserve the downloaded archives and original `gt.csv` unchanged, report duplicate annotations, and fail on unknown labels or split leakage rather than guessing.

The source dataset is licensed CC BY 4.0. Cite [VarroaDataset, Zenodo record 4085044](https://zenodo.org/records/4085044) when using results. The images are controlled, individual-bee crops at 160 × 280, not whole-hive photos. Model performance on these crops does not establish performance on phone photos or Sri Lankan field conditions.

## Dataset inspection and splits

The official release has 13,509 annotation rows, with published train/validation/test counts of 8,225 / 1,876 / 3,408. The inspected `gt.csv` has 13,507 unique paths because two rows repeat a training image path. The audit records perceptual-hash candidates and checks them with aligned-image structural similarity. It found three cross-split candidates, but their global SSIM scores are below 0.52 and visual review showed different captures, so none is confirmed as a near duplicate. Source-video groups are disjoint across the official splits. The official split is therefore retained; the manifests include the original split provenance and the reports preserve the candidate details.

The audit found no unreadable, missing, or wrong-sized images, no exact duplicate image bytes, and no source-video group shared across the original splits. It found one invalid bounding box. Bounding boxes are not used by this classifier; the image and its image-level class label remain included, while the invalid box is reported and the original `gt.csv` stays unchanged. Duplicate annotation rows are reduced to one classifier-manifest entry per image, with both repeats recorded.

## 1. Set up an isolated CPU environment

Commands below are for Windows PowerShell from the repository root. Python 3.11 is used for the ML environment; this does not modify the FastAPI environment or application dependencies.

```powershell
py -3.11 -m venv backend\ml\model_a_varroa_classifier\.venv
backend\ml\model_a_varroa_classifier\.venv\Scripts\python.exe -m pip install --upgrade pip
backend\ml\model_a_varroa_classifier\.venv\Scripts\python.exe -m pip install -r backend\ml\model_a_varroa_classifier\requirements.txt
```

## 2. Download the official data if it is not already present

Keep original downloads separate from prepared data and from the existing `DATAESET\archive.zip` dataset.

```powershell
$source = 'C:\Users\User\OneDrive\Desktop\Y4S1 NOTES\Reserach\DATAESET\VarroaDataset_original'
New-Item -ItemType Directory -Force -Path $source | Out-Null
curl.exe --fail --location --output "$source\train.zip" 'https://zenodo.org/records/4085044/files/train.zip?download=1'
curl.exe --fail --location --output "$source\val.zip" 'https://zenodo.org/records/4085044/files/val.zip?download=1'
curl.exe --fail --location --output "$source\test.zip" 'https://zenodo.org/records/4085044/files/test.zip?download=1'
curl.exe --fail --location --output "$source\gt.csv" 'https://zenodo.org/records/4085044/files/gt.csv?download=1'
```

## 3. Inspect and prepare

```powershell
$python = 'backend\ml\model_a_varroa_classifier\.venv\Scripts\python.exe'
$source = 'C:\Users\User\OneDrive\Desktop\Y4S1 NOTES\Reserach\DATAESET\VarroaDataset_original'
$prepared = 'C:\Users\User\OneDrive\Desktop\Y4S1 NOTES\Reserach\DATAESET\VarroaDataset_prepared'
& $python backend\ml\model_a_varroa_classifier\inspect_dataset.py --source $source --verify-checksums --output backend\ml\model_a_varroa_classifier\reports\dataset_inspection.json
& $python backend\ml\model_a_varroa_classifier\prepare_dataset.py --source $source --output $prepared --report-copy backend\ml\model_a_varroa_classifier\reports\preparation_report.json
```

Preparation extracts copies to `$prepared\raw`, validates images and annotations, checks exact and perceptual duplicates, and writes official-split manifests under `$prepared\manifests`. Original archives remain unchanged. At model input, images are resized with aspect ratio preserved to fit 224 x 224, padded with the pretrained RGB mean, and normalized with the exact ImageNet mean and standard deviation for `MobileNet_V2_Weights.IMAGENET1K_V1`. This avoids the preset's center crop removing much of the tall 160 x 280 bee crop. Only training receives horizontal flip, a small rotation, and mild color jitter; validation and test receive deterministic resize and normalization only.

## 4. Train and evaluate

```powershell
$python = 'backend\ml\model_a_varroa_classifier\.venv\Scripts\python.exe'
$prepared = 'C:\Users\User\OneDrive\Desktop\Y4S1 NOTES\Reserach\DATAESET\VarroaDataset_prepared'
$artifacts = 'backend\ml\model_a_varroa_classifier\artifacts'
& $python backend\ml\model_a_varroa_classifier\train.py --prepared-dir $prepared --output-dir $artifacts --seed 2026 --batch-size 32 --head-epochs 5 --finetune-epochs 8 --patience 3
& $python backend\ml\model_a_varroa_classifier\evaluate.py --prepared-dir $prepared --model-dir $artifacts
```

Training freezes the backbone while fitting the new two-class head, then fine-tunes the final backbone blocks. It uses validation data for early stopping, checkpoint selection, and positive-class threshold selection. The test set is used once by `evaluate.py`, after training. The reported outputs include accuracy, class precision/recall/F1, confusion matrix, ROC-AUC, and especially Varroa-positive recall on the untouched official test split.

Generated artifacts include `best_model.pt`, `class_map.json`, `preprocessing.json`, `training_config.json`, `training_history.csv`, `preparation_report.json`, `test_evaluation.json`, and per-image test predictions. Checkpoints are ignored by the repository's `*.pt` rule; dataset downloads and prepared copies live outside the repository.

There is no existing Custom CNN checkpoint or training pipeline in this project, so a same-split comparison cannot currently be reported. This model is separate from the app's current four-class inference contract; this work does not change Flutter or FastAPI inference integration.
