from datetime import datetime

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.core.database import Base
from app.models.category import Category, RecordType
from app.models.record import Record
from app.models.user import User
from app.models.wallet_budget import WalletBudget
from app.models.wallet_category_binding import WalletCategoryBinding
from app.services.wallet_service import bind_wallet_category, calculate_wallet_spend


def session():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    return Session(engine)


def seed(db):
    db.add(User(id=1, username="u1", password_hash="x"))
    db.add_all([
        Category(id=1, name="餐饮", type=RecordType.expense),
        Category(id=2, parent_id=1, name="早餐", type=RecordType.expense),
        Category(id=3, parent_id=1, name="午餐", type=RecordType.expense),
        Category(id=4, parent_id=1, name="晚餐", type=RecordType.expense),
    ])
    food = WalletBudget(id=1, user_id=1, wallet_type="custom", name="一日三餐", amount=1500, sort_order=0)
    lunch = WalletBudget(id=2, user_id=1, wallet_type="custom", name="午餐", amount=500, sort_order=1)
    db.add_all([food, lunch])
    db.add_all([
        Record(user_id=1, type=RecordType.expense, amount=12, category_id=2, date="2026-09-01"),
        Record(user_id=1, type=RecordType.expense, amount=20, category_id=3, date="2026-09-02"),
        Record(user_id=1, type=RecordType.expense, amount=25, category_id=4, date="2026-09-03"),
    ])
    db.commit()
    return food, lunch


def test_parent_binding_includes_descendants():
    db = session()
    food, _ = seed(db)
    bind_wallet_category(db, food.id, 1, include_descendants=True)
    result = calculate_wallet_spend(db, user_id=1, month="2026-09")
    assert result[food.id] == 57.0


def test_leaf_binding_beats_parent_binding():
    db = session()
    food, lunch = seed(db)
    bind_wallet_category(db, food.id, 1, include_descendants=True)
    bind_wallet_category(db, lunch.id, 3, include_descendants=False)
    result = calculate_wallet_spend(db, user_id=1, month="2026-09")
    assert result[lunch.id] == 20.0
    assert result[food.id] == 37.0
