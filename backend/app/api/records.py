from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.record import Record
from app.models.category import Category
from app.models.user import User
from app.schemas.record import RecordCreate, RecordUpdate, RecordOut
from app.schemas.common import success, error
from app.services.record_writer import create_record as create_idempotent_record

router = APIRouter(prefix="/records", tags=["记账"])


def _record_out(r: Record) -> dict:
    """将 Record ORM 对象转为响应格式，附带分类名和 emoji。"""
    cat = r.category if hasattr(r, 'category') and r.category else None
    return {
        "id": r.id,
        "type": r.type.value if hasattr(r.type, 'value') else r.type,
        "amount": r.amount,
        "category_id": r.category_id,
        "category_name": cat.name if cat else "",
        "category_emoji": cat.emoji if cat else None,
        "date": r.date,
        "note": r.note,
    }


@router.get("")
def get_records(
    month: Optional[str] = None,
    year: Optional[str] = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    q = db.query(Record).options(joinedload(Record.category)).filter(Record.user_id == user.id)

    if month:
        q = q.filter(Record.date.startswith(month))
    elif year:
        q = q.filter(Record.date.startswith(year))

    records = q.order_by(Record.date.desc(), Record.id.desc()).all()
    return success(data=[_record_out(r) for r in records])


@router.post("")
def create_record(
    data: RecordCreate,
    idempotency_key: Optional[str] = Header(default=None, alias="Idempotency-Key"),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # 校验分类存在
    cat = db.query(Category).filter(Category.id == data.category_id).first()
    if not cat:
        return error(400, "分类不存在")

    if idempotency_key:
        cached = create_idempotent_record(db, user.id, idempotency_key, {
            "type": data.type, "amount": data.amount, "category_id": data.category_id,
            "date": data.date, "note": data.note,
        })
        record = db.query(Record).options(joinedload(Record.category)).filter(Record.id == cached["record_id"]).first()
        return success(data=_record_out(record))

    record = Record(
        user_id=user.id,
        type=data.type,
        amount=data.amount,
        category_id=data.category_id,
        date=data.date,
        note=data.note,
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    # 重新加载带关联的 record
    record = db.query(Record).options(joinedload(Record.category)).filter(Record.id == record.id).first()
    return success(data=_record_out(record))


@router.put("/{record_id}")
def update_record(
    record_id: int,
    data: RecordUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    record = db.query(Record).filter(Record.id == record_id, Record.user_id == user.id).first()
    if not record:
        return error(404, "记录不存在")

    allowed_fields = {"date", "category_id", "amount", "note", "type"}
    if data.field not in allowed_fields:
        return error(400, f"不允许修改字段: {data.field}")

    value = data.value
    if data.field == "amount" and value is not None:
        value = float(value)

    setattr(record, data.field, value)
    db.commit()
    return success()


@router.delete("/{record_id}")
def delete_record(
    record_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    record = db.query(Record).filter(Record.id == record_id, Record.user_id == user.id).first()
    if not record:
        return error(404, "记录不存在")

    db.delete(record)
    db.commit()
    return success()


@router.delete("")
def delete_all_records(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """批量删除当前用户所有记录"""
    count = db.query(Record).filter(Record.user_id == user.id).delete()
    db.commit()
    return success(data={"deleted": count})
