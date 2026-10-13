import json
from sqlalchemy.orm import Session
from app.models.idempotency_request import IdempotencyRequest
from app.models.record import Record


def create_record(db: Session, user_id: int, request_id: str, payload: dict):
    cached = db.query(IdempotencyRequest).filter_by(user_id=user_id, request_id=request_id).first()
    if cached:
        return json.loads(cached.response_json)
    record = Record(user_id=user_id, **payload)
    db.add(record)
    db.flush()
    response = {"record_id": record.id}
    db.add(IdempotencyRequest(user_id=user_id, request_id=request_id, response_json=json.dumps(response)))
    db.commit()
    return response
