import pytest
from fastapi import HTTPException
from app.routes import IT23183186_image_inference as images
from app.services import IT23183186_environment_history as history
from test_image_inference import make_client, image_upload


def test_save_image_analysis_requires_hive():
    response=make_client().post('/api/v1/inference/analyze',data={'save_result':'true'},
        files={'outside_image':('bee.png',image_upload(),'image/png')})
    assert response.status_code == 422


def test_image_result_saves_server_assessment_without_photo_bytes(monkeypatch):
    monkeypatch.setattr(history,'hive_location',lambda hive,user:'7.29,80.63')
    async def build(q,hive_id,user_id,a,b):
        return {'assessment':{'status':'inconclusive'},'weather':None,'sensor':None,'environment':None}
    monkeypatch.setattr(images,'build_assessment',build)
    saved=[]
    def store(hive,user,location,snapshot,source):
        saved.append((hive,user,location,snapshot,source));return {'id':'record-1'}
    monkeypatch.setattr(history,'save_snapshot',store)
    response=make_client().post('/api/v1/inference/analyze',data={'save_result':'true','hive_id':'mine'},
        files={'outside_image':('bee.png',image_upload(),'image/png')})
    assert response.status_code == 200
    assert response.json()['saved_record_id'] == 'record-1'
    hive,user,location,snapshot,source=saved[0]
    assert (hive,user,location) == ('mine','test-user','7.29,80.63')
    assert snapshot['record_type'] == 'image_assessment'
    assert snapshot['model_a']['predicted_class'] == 'healthy'
    assert snapshot['image_inputs'] == {'individual_bee':True,'hive_frame':False}
    assert not any(isinstance(v,bytes) for v in snapshot.values())


def test_image_history_cannot_save_for_foreign_hive(monkeypatch):
    def reject(*args):raise HTTPException(404,'Hive not found.')
    monkeypatch.setattr(history,'hive_location',reject)
    response=make_client().post('/api/v1/inference/analyze',data={'save_result':'true','hive_id':'foreign'},
        files={'outside_image':('bee.png',image_upload(),'image/png')})
    assert response.status_code == 404


def test_failed_history_write_preserves_inference_result(monkeypatch):
    monkeypatch.setattr(history,'hive_location',lambda *args:'Kandy')
    async def build(*args):return {'assessment':{'status':'inconclusive'}}
    monkeypatch.setattr(images,'build_assessment',build)
    def fail(*args):raise RuntimeError('database unavailable')
    monkeypatch.setattr(history,'save_snapshot',fail)
    response=make_client().post('/api/v1/inference/analyze',data={'save_result':'true','hive_id':'mine'},
        files={'outside_image':('bee.png',image_upload(),'image/png')})
    assert response.status_code == 200
    assert response.json()['model_a']['status'] == 'complete'
    assert response.json()['save_error']
    assert 'saved_record_id' not in response.json()
