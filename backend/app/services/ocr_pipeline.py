from __future__ import annotations

from dataclasses import dataclass
from sqlalchemy.orm import Session
from app.models.category import Category
from app.models.merchant_category_rule import MerchantCategoryRule

@dataclass(frozen=True)
class CategoryCandidate:
    category_id: int | None
    category_name: str | None
    parent_category_id: int | None
    specificity: str | None
    source: str
    confidence: float

def resolve_category(db: Session, name: str | None) -> CategoryCandidate:
    if not name:
        return CategoryCandidate(None, None, None, None, "none", 0)
    categories = db.query(Category).all()
    exact = next((c for c in categories if c.name == name), None)
    if exact:
        return CategoryCandidate(exact.id, exact.name, exact.parent_id or exact.id, "leaf" if exact.parent_id else "parent", "vision", 1)
    return CategoryCandidate(None, None, None, None, "none", 0)


def normalize_merchant(value: str) -> str:
    return "".join(value.strip().lower().split())[:100]


def lookup_merchant_category(db: Session, user_id: int, merchant: str):
    key = normalize_merchant(merchant)
    if not key:
        return None
    return db.query(MerchantCategoryRule).filter(
        MerchantCategoryRule.user_id == user_id,
        MerchantCategoryRule.merchant_key == key,
        MerchantCategoryRule.confirmations >= 2,
    ).first()


def learn_merchant_category(db: Session, user_id: int, merchant: str, category_id: int):
    key = normalize_merchant(merchant)
    if not key:
        return None
    rule = db.query(MerchantCategoryRule).filter_by(user_id=user_id, merchant_key=key).first()
    if rule is None:
        rule = MerchantCategoryRule(user_id=user_id, merchant_key=key, category_id=category_id, confirmations=1)
        db.add(rule)
    elif rule.category_id == category_id:
        rule.confirmations += 1
    else:
        rule.category_id = category_id
        rule.confirmations = 1
    db.commit()
    db.refresh(rule)
    return rule
