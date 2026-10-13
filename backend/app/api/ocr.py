from typing import Optional
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.category import Category
from app.services.llm_parser import parse_receipt
from app.services.ocr_pipeline import resolve_category, lookup_merchant_category, learn_merchant_category
import base64
import hashlib
import json
from datetime import datetime, timedelta, timezone
from app.models.ocr_cache import OcrCache

router = APIRouter(prefix="/ai", tags=["AI-OCR"])


class OcrRequest(BaseModel):
    image_base64: str


class OcrConfirmation(BaseModel):
    merchant: str
    category_id: int


def _resolve_category_id(db: Session, category_name: Optional[str]) -> Optional[int]:
    if not category_name: return None
    cat = db.query(Category).filter(Category.name == category_name, Category.parent_id.isnot(None)).first()
    if cat: return cat.id
    cats = db.query(Category).filter(Category.parent_id.isnot(None)).all()
    for c in cats:
        if c.name and category_name in c.name: return c.id
    return None


@router.post("/ocr", response_model=dict)
def ocr_single(req: OcrRequest, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        image_bytes = base64.b64decode(req.image_base64, validate=True)
    except Exception:
        return {"code": 1, "message": "图片数据无效"}

    image_hash = hashlib.sha256(str(user.id).encode() + image_bytes).hexdigest()
    cached = db.query(OcrCache).filter(
        OcrCache.user_id == user.id,
        OcrCache.image_hash == image_hash,
        OcrCache.expires_at > datetime.now(timezone.utc).replace(tzinfo=None),
    ).first()
    if cached:
        return {"code": 0, "data": json.loads(cached.payload_json), "cached": True}

    # 通义千问 VL 直接识别截图
    items = parse_receipt(req.image_base64, db)

    if not items:
        return {"code": 1, "message": "未能识别消费信息，请尝试手动输入"}

    for item in items:
        learned = lookup_merchant_category(db, user.id, item.get("merchant", ""))
        candidate = resolve_category(db, item.get("category"))
        if learned is not None:
            learned_category = db.query(Category).filter(Category.id == learned.category_id).first()
            candidate = resolve_category(db, learned_category.name if learned_category else None)
        item["category_id"] = candidate.category_id
        item["category_confidence"] = candidate.confidence
        item["category_specificity"] = candidate.specificity

    db.add(OcrCache(
        user_id=user.id,
        image_hash=image_hash,
        payload_json=json.dumps(items, ensure_ascii=False),
        expires_at=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(hours=24),
    ))
    db.commit()
    return {"code": 0, "data": items, "cached": False}


@router.post("/ocr/confirm", response_model=dict)
def confirm_ocr_category(req: OcrConfirmation, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if db.query(Category.id).filter(Category.id == req.category_id).first() is None:
        return {"code": 1, "message": "分类不存在"}
    learn_merchant_category(db, user.id, req.merchant, req.category_id)
    return {"code": 0, "message": "分类习惯已记录"}
