import json
from pathlib import Path
from types import SimpleNamespace
from fastapi import FastAPI
from fastapi.testclient import TestClient
from app.core.security import get_current_user_id
from app.routes.IT23183186_image_inference import router
from app.services.IT23183186_model_reports import model_report


def artifacts(tmp_path):
    run = tmp_path / "active_run"
    run.mkdir()
    checkpoint = run / "model.pt"
    checkpoint.write_bytes(b"test fixture")
    (run / "model_metadata.json").write_text(json.dumps({"dataset": "test dataset"}))
    (run / "preprocessing.json").write_text(json.dumps({"architecture": "MobileNetV2", "input_shape": [3, 224, 224]}))
    (run / "training_history.csv").write_text("epoch,train_loss,val_loss,val_accuracy\n1,0.8,0.9,0.6\n2,0.5,0.7,0.7\n")
    return run, checkpoint


def test_active_run_history_does_not_borrow_another_runs_metrics(tmp_path):
    run, checkpoint = artifacts(tmp_path)
    other = tmp_path / "other_run"
    other.mkdir()
    (other / "test_evaluation.json").write_text(json.dumps({"accuracy": .99, "checkpoint": str(other / "model.pt"), "split": "test"}))
    report = model_report("model_a", checkpoint)
    assert report["evaluation"] is None
    assert report["history"][1]["val_accuracy"] == .7
    assert report["history"][0]["train_accuracy"] is None
    assert str(tmp_path) not in json.dumps(report)


def test_matching_heldout_report_preserves_counts_and_class_metrics(tmp_path):
    run, checkpoint = artifacts(tmp_path)
    (run / "evaluation").mkdir()
    file = run / "evaluation/test_evaluation.json"
    evaluation = {"checkpoint": str(checkpoint), "split": "test", "accuracy": .8, "test_count": 10, "confusion_matrix": [[4,1],[1,4]], "confusion_matrix_labels_order": ["healthy", "varroa_positive"], "per_class": {"healthy": {"precision": .8, "recall": .8}}, "test_manifest": "private/file.csv"}
    file.write_text(json.dumps(evaluation))
    report = model_report("model_a", checkpoint)
    assert report["evaluation"]["test_count"] == 10
    assert report["evaluation"]["confusion_matrix"] == [[4,1],[1,4]]
    assert "test_manifest" not in report["evaluation"]
    evaluation["checkpoint"] = str(tmp_path / "wrong.pt")
    file.write_text(json.dumps(evaluation))
    assert model_report("model_a", checkpoint)["evaluation"] is None
    evaluation["checkpoint"] = str(checkpoint)
    evaluation["split"] = "val"
    file.write_text(json.dumps(evaluation))
    assert model_report("model_a", checkpoint)["evaluation"] is None


def test_missing_corrupt_and_detector_reports_are_explicit(tmp_path):
    run, checkpoint = artifacts(tmp_path)
    (run / "test_evaluation.json").write_text("invalid json")
    assert model_report("model_a", checkpoint)["evaluation_status"] == "unavailable"
    weights = tmp_path / "detector/weights/best.pt"
    weights.parent.mkdir(parents=True)
    weights.write_bytes(b"test fixture")
    (weights.parent.parent / "results.csv").write_text("epoch,train/box_loss,val/box_loss\n1,1.2,1.4\n")
    report = model_report("model_b", weights)
    assert report["history"][0]["train_loss"] == 1.2
    assert report["history"][0]["val_accuracy"] is None
    assert report["evaluation"] is None


def test_reports_route_requires_auth_and_uses_loaded_checkpoint(tmp_path):
    _, checkpoint = artifacts(tmp_path)
    app = FastAPI()
    app.include_router(router, prefix="/api/v1")
    app.state.image_model_service = SimpleNamespace(models={"model_a": {"checkpoint": str(checkpoint)}})
    client = TestClient(app)
    assert client.get("/api/v1/inference/reports/model_a").status_code in (401,403)
    app.dependency_overrides[get_current_user_id] = lambda: "test-user"
    response = client.get("/api/v1/inference/reports/model_a")
    assert response.status_code == 200
    assert response.json()["run_id"] == "active_run"
    assert client.get("/api/v1/inference/reports/unknown").status_code == 404


def test_detector_evaluator_exports_actual_axes_and_detection_metrics(tmp_path, monkeypatch):
    import importlib.util
    import sys
    import numpy as np
    source = Path(__file__).resolve().parents[1] / "models/IT23183186_model_b_hive_frame_detector/evaluate.py"
    metrics = SimpleNamespace(results_dict={"metrics/mAP50(B)": .6}, confusion_matrix=SimpleNamespace(matrix=np.array([[4, 1, 2], [3, 5, 1], [2, 4, 0]])), box=SimpleNamespace(ap_class_index=[0,1], p=[.7,.8], r=[.6,.5], f1=[.64,.61]))
    model = SimpleNamespace(names={0: "structure_a", 1: "structure_b"}, val=lambda **kwargs: metrics)
    monkeypatch.setitem(sys.modules, "model", SimpleNamespace(create_yolo11n=lambda _: model, read_dataset_yaml=lambda *args, **kwargs: {}))
    spec = importlib.util.spec_from_file_location("detector_eval_fixture", source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    weights = tmp_path / "weights.pt"
    weights.write_bytes(b"fixture")
    monkeypatch.setattr(sys, "argv", ["evaluate.py", "--data", str(tmp_path / "data.yaml"), "--weights", str(weights), "--project", str(tmp_path), "--name", "run_test"])
    module.main()
    report = json.loads((tmp_path / "run_test/test_evaluation.json").read_text())
    assert report["confusion_matrix"] == [[4,3,2],[1,5,4],[2,1,0]]
    assert report["confusion_matrix_labels_order"] == ["structure_a", "structure_b", "background"]
    assert report["per_class"]["structure_a"]["precision"] == .7
    assert "accuracy" not in report
    assert "test_count" not in report
    assert report["split"] == "test" and report["evaluation_date"]


def test_active_research_artifacts_are_consistent_if_present():
    root=Path(__file__).resolve().parents[1]
    directory=root/'models/IT23183186_model_a_varroa_classifier/artifacts/IT23183186_ModelA_20261021_203515'
    report_file=directory/'evaluation/test_evaluation.json'
    if not report_file.is_file():
        import pytest
        pytest.skip('Research outputs are generated locally, not required in CI')
    report=json.loads(report_file.read_text())
    matrix=report['confusion_matrix']
    assert sum(sum(row) for row in matrix)==report['test_count']
    assert sum(matrix[i][i] for i in range(len(matrix)))/report['test_count']==report['accuracy']
    assert report['split']=='test' and report['test_set_used_for_model_selection'] is False
    assert report['checkpoint'].endswith('IT23183186_ModelA_MobileNetV2.pt')
