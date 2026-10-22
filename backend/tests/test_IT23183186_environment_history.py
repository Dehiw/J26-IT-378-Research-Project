from copy import deepcopy

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.security import get_current_user_id
from app.routes import IT23183186_environment as routes
from app.services import IT23183186_environment_history as history


class Document:
    def __init__(self, db, path):
        self.db, self.path = db, path
        self.id = path[-1]

    @property
    def exists(self):
        return self.path in self.db.data

    def get(self):
        return self

    def to_dict(self):
        return deepcopy(self.db.data.get(self.path))

    def set(self, value):
        self.db.data[self.path] = deepcopy(value)

    def collection(self, name):
        return Collection(self.db, (*self.path, name))


class Collection:
    def __init__(self, db, path):
        self.db, self.path, self.count = db, path, 100

    def document(self, name):
        return Document(self.db, (*self.path, name))

    def order_by(self, field, direction):
        assert field == "saved_at" and direction == "DESCENDING"
        return self

    def limit(self, count):
        self.count = count
        return self

    def stream(self):
        docs = [Document(self.db, p) for p in self.db.data
                if p[:-1] == self.path]
        return sorted(docs, key=lambda d: d.to_dict()["saved_at"], reverse=True)[:self.count]


class Database:
    def __init__(self):
        self.data = {
            ("hives", "mine"): {"user_id": "owner", "apiary_id": "yard", "name": "Clover"},
            ("hives", "foreign"): {"user_id": "someone-else", "apiary_id": "yard"},
            ("apiaries", "yard"): {"user_id": "owner", "gps_location": "7.29,80.63"},
        }

    def collection(self, name):
        return Collection(self, (name,))


def client(auth=True):
    app = FastAPI()
    app.include_router(routes.router)
    if auth:
        app.dependency_overrides[get_current_user_id] = lambda: "owner"
    return TestClient(app)


@pytest.fixture
def database(monkeypatch):
    db = Database()
    monkeypatch.setattr(history, "_database", lambda: db)
    return db


def test_records_require_authentication():
    for method in ("get", "post"):
        assert getattr(client(False), method)("/environment/hives/mine/records").status_code == 401


@pytest.mark.parametrize("hive", ["foreign", "missing"])
def test_other_users_and_missing_hives_cannot_read_or_save(database, hive):
    for method in ("get", "post"):
        assert getattr(client(), method)(f"/environment/hives/{hive}/records").status_code == 404
    assert not any(history.COLLECTION in p for p in database.data)


def test_save_and_reload_preserves_evidence_and_uses_saved_location(database, monkeypatch):
    snapshot = {"assessment": {"status": "inconclusive", "rules_version": "v1", "missing_inputs": ["sensors"]},
                "weather": {"current": {"temperature_c": 28, "last_updated": "2026-10-21 12:00"}},
                "sensor": None, "environment": {"season": "Inter-monsoon"}, "weather_error": None}
    async def build(q, hive_id, user_id):
        assert (q, hive_id, user_id) == ("7.29,80.63", "mine", "owner")
        return snapshot
    monkeypatch.setattr(routes, "build_assessment", build)
    response = client().post("/environment/hives/mine/records")
    assert response.status_code == 201
    record = response.json()["record"]
    assert record["user_id"] == "owner" and record["apiary_id"] == "yard"
    assert record["hive_id"] == "mine" and record["location_source"] == "saved_apiary"
    assert record["weather"] == snapshot["weather"] and record["sensor"] is None
    assert record["saved_at"].endswith("+00:00")
    stored = database.data[("hives", "mine", history.COLLECTION, record["id"])]
    assert stored == record
    assert client().get("/environment/hives/mine/records").json()["records"] == [record]


def test_partial_snapshot_explicit_location_and_order_limit(database, monkeypatch):
    async def build(q, hive_id, user_id):
        assert q == "Galle"
        return {"weather": None, "sensor": None, "assessment": {"status": "inconclusive"},
                "weather_error": "Outdoor weather unavailable"}
    monkeypatch.setattr(routes, "build_assessment", build)
    first = client().post("/environment/hives/mine/records?q=Galle").json()["record"]
    second = client().post("/environment/hives/mine/records?q=Galle").json()["record"]
    assert first["id"] != second["id"]
    assert second["location_source"] == "explicit_query" and second["weather"] is None
    assert client().get("/environment/hives/mine/records?limit=1").json()["records"] == [second]
    assert client().get("/environment/hives/mine/records?limit=101").status_code == 422


def test_history_failure_has_safe_error(database, monkeypatch):
    def fail(*args):
        raise RuntimeError("private infrastructure detail")
    monkeypatch.setattr(history, "list_snapshots", fail)
    response = client().get("/environment/hives/mine/records")
    assert response.status_code == 503
    assert "private" not in response.text


def test_transferred_hive_does_not_expose_prior_owner_records(database):
    database.data[("hives", "mine", history.COLLECTION, "old")] = {
        "user_id": "previous-owner", "saved_at": "2026-10-21T00:00:00+00:00"}
    assert client().get("/environment/hives/mine/records").json()["records"] == []
