from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from app.core.database import Base
from app.models.category import Category, RecordType
from app.models.user import User
from app.services.record_writer import create_record


def test_same_user_and_request_key_creates_one_record():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    db = Session(engine)
    db.add_all([User(id=1, username="u", password_hash="x"), Category(id=1, name="餐饮", type=RecordType.expense)])
    db.commit()
    payload = {"type": RecordType.expense, "amount": 2, "category_id": 1, "date": "2026-09-15"}
    first = create_record(db, 1, "abc", payload)
    second = create_record(db, 1, "abc", payload)
    assert first == second
    assert db.query("records") if False else db.query(__import__('app.models.record', fromlist=['Record']).Record).count() == 1
