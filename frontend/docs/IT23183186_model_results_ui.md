# Model analysis results

The image-analysis screen keeps one upload area per model. The preview in each results panel uses the uploaded XFile for that request; photos are not persisted in history.

Prediction outputs and evaluation reports are separate. GET /api/v1/inference/reports/model_a and /model_b require the existing bearer authentication. The endpoint reads the loaded checkpoint's run directory (or the configured checkpoint when unavailable). It never borrows metrics from an unrelated run. A report must identify the same checkpoint and an explicit held-out test split.

## Artifacts

Model A reads training_config.json, preprocessing.json, class_map.json, model_metadata.json, and training_history.csv from the checkpoint directory. Held-out results must be saved as evaluation/test_evaluation.json (or test_evaluation.json) in that directory. The existing evaluate.py writes per-class metrics, test count, a labelled confusion matrix, and test_predictions.csv; future evaluations also record evaluation_date. Use the training environment to run:

```powershell
python models/IT23183186_model_a_varroa_classifier/evaluate.py --prepared-dir "<prepared dataset directory>" --model-dir "<active checkpoint directory>"
```

Model B reads results.csv and args.yaml from the YOLO run directory above weights/. Logged box loss is labelled Box loss; absent classification accuracy is not invented. Held-out results may be saved at evaluation/test_evaluation.json or in the matching run's *_test directory produced by evaluate.py. For a differently named evaluation directory, copy its report into the matching training run/evaluation directory; its checkpoint field must still match. Detection metrics remain distinct from classification accuracy.

Missing or unreadable reports produce empty states. A prediction score is never used as test accuracy. An evaluation date is shown only when recorded in the report, never inferred from a prediction timestamp or filesystem modification time. No training or evaluation is automatically launched when opening results.

The active Model A run now has its own held-out report from the existing evaluator: 3,408 test images, 77.49% accuracy, 64.60% macro F1, and 74.15% weighted F1. Varroa-positive recall is 31.00%, an important limitation. Its 13 saved epochs are displayed; training accuracy was not logged and is not synthesized. Model B's report availability depends on its configured trained artifacts.

Restart the backend after deploying the new reports route. Refresh/rebuild Flutter to load the updated results view. API multipart fields, authentication, assessment, and save flows remain compatible.

Model B future evaluations also export per-class detection precision/recall/F1 and, when provided by Ultralytics, raw confusion counts including background. Matrix axes are transposed to rows=actual, columns=predicted, following the [Ultralytics metric convention](https://docs.ultralytics.com/reference/utils/metrics/#ultralytics.utils.metrics.ConfusionMatrix). No classification accuracy or weighted aggregate is synthesized for detection.
