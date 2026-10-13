from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from app.core.database import Base
from app.models.category import Category, RecordType
from app.services.ocr_pipeline import resolve_category, learn_merchant_category, lookup_merchant_category

def test_unknown_category_stays_unselected():
    engine = create_engine("sqlite:///:memory:"); Base.metadata.create_all(engine); db = Session(engine)
    db.add(Category(id=1, name="餐饮", type=RecordType.expense)); db.commit()
    result = resolve_category(db, "不存在")
    assert result.category_id is None and result.confidence == 0

def test_root_category_can_be_resolved():
    engine = create_engine("sqlite:///:memory:"); Base.metadata.create_all(engine); db = Session(engine)
    db.add(Category(id=1, name="餐饮", type=RecordType.expense)); db.commit()
    result = resolve_category(db, "餐饮")
    assert result.category_id == 1 and result.specificity == "parent"


def test_rule_activates_after_two_equal_confirmations_and_is_user_scoped():
    engine = create_engine("sqlite:///:memory:"); Base.metadata.create_all(engine); db = Session(engine)
    db.add(Category(id=7, name="奶茶咖啡", type=RecordType.expense)); db.commit()
    learn_merchant_category(db, 1, " 瑞幸咖啡 ", 7)
    assert lookup_merchant_category(db, 1, "瑞幸咖啡") is None
    learn_merchant_category(db, 1, "瑞幸咖啡", 7)
    assert lookup_merchant_category(db, 1, "瑞幸咖啡").category_id == 7
    assert lookup_merchant_category(db, 2, "瑞幸咖啡") is None
