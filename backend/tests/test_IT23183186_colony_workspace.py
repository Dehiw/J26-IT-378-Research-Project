import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from app.core.security import get_current_user_id
from app.routes import IT23183186_environment as routes
from app.services import IT23183186_environment_history as history
from app.services import IT23183186_colony_workspace as workspace
from test_IT23183186_environment_history import Database


def client(auth=True):
    app = FastAPI()
    app.include_router(routes.router)
    if auth: app.dependency_overrides[get_current_user_id] = lambda: "owner"
    return TestClient(app)

@pytest.fixture
def db(monkeypatch):
    database = Database()
    database.data[("hives", "mine")]["num_frames"] = 8
    monkeypatch.setattr(history, "_database", lambda: database)
    monkeypatch.setattr(workspace, "_sensor_history", lambda hive: [])
    async def monitoring(q, hive_id, user_id):
        return {"weather": None, "sensor": None, "assessment": {"status": "inconclusive", "alerts": [], "evidence": {}}}
    monkeypatch.setattr(routes, "build_assessment", monitoring)
    return database


def test_workspace_requires_authentication_and_ownership(db):
    assert client(False).get('/environment/hives/mine/workspace').status_code == 401
    assert client().get('/environment/hives/foreign/workspace').status_code == 404
    assert client().post('/environment/hives/foreign/observations', json={'observed_on':'2020-01-01','notes':'Checked'}).status_code == 404


def test_observation_save_reload_and_limits(db):
    url = '/environment/hives/mine/observations'
    assert client().post(url, json={'observed_on':'2020-01-01'}).status_code == 422
    assert client().post(url, json={'observed_on':'2099-01-01','notes':'Checked'}).status_code == 422
    assert client().post(url, json={'observed_on':'2020-01-01','brood_frames':9}).status_code == 422
    response = client().post(url, json={'observed_on':'2020-01-01','food_stores':'light','bee_activity':'low','brood_frames':3})
    assert response.status_code == 201
    body = client().get('/environment/hives/mine/workspace').json()
    assert body['observations'][0]['food_stores'] == 'light'
    assert body['observations'][0]['user_id'] == 'owner'
    assert body['models']['model_a']['available'] is False
    assert body['monitoring']['assessment']['status'] == 'inconclusive'


def test_care_plan_requires_expert_record_and_can_be_completed(db):
    url = '/environment/hives/mine/care-plans'
    assert client().post(url, json={'action':'treatment_record','due_on':'2020-01-01','notes':'Follow expert plan'}).status_code == 422
    response = client().post(url, json={'action':'inspect','due_on':'2020-01-01','notes':'Review food stores'})
    assert response.status_code == 201
    record = response.json()['record']
    assert record['status'] == 'planned'
    completed = client().post(f"{url}/{record['id']}/complete")
    assert completed.status_code == 200 and completed.json()['record']['status'] == 'completed'
    assert client().post('/environment/hives/foreign/care-plans/'+record['id']+'/complete').status_code == 404
    assert client().post(url+'/missing/complete').status_code == 404


def test_preferences_validated_and_persisted(db):
    url='/environment/hives/mine/preferences'
    assert client().put(url,json={'refresh_seconds':1}).status_code == 422
    assert client().put(url,json={'auto_refresh':False,'refresh_seconds':900,'in_app_alerts':False}).status_code == 200
    prefs=client().get('/environment/hives/mine/workspace').json()['preferences']
    assert prefs['auto_refresh'] is False and prefs['refresh_seconds'] == 900


def test_alert_reviews_are_owned_and_idempotent(db):
    snapshot={'assessment':{'alerts':[{'id':'rain','source':'WeatherAPI','message':'Rain'}]},'weather':{'current':{'last_updated_epoch':123}}}
    key=workspace.keyed_alerts(snapshot)['assessment']['alerts'][0]['review_key']
    url='/environment/hives/mine/alert-reviews'
    assert client().post(url,json={'key':'bad'}).status_code == 422
    for _ in range(2): assert client().post(url,json={'key':key}).status_code == 201
    reviews=client().get('/environment/hives/mine/workspace').json()['alert_reviews']
    assert len(reviews) == 1 and reviews[0]['key'] == key
    newer={'assessment':{'alerts':[{'id':'rain','source':'WeatherAPI','message':'Rain'}]},'weather':{'current':{'last_updated_epoch':124}}}
    assert workspace.keyed_alerts(newer)['assessment']['alerts'][0]['review_key'] != key


def test_sensor_failure_preserves_other_workspace_records(db, monkeypatch):
    def unavailable(hive): raise RuntimeError('private endpoint')
    monkeypatch.setattr(workspace,'_sensor_history',unavailable)
    response=client().get('/environment/hives/mine/workspace')
    assert response.status_code == 200
    assert response.json()['sensor_history'] == [] and response.json()['sensor_error']
    assert 'private endpoint' not in response.text
