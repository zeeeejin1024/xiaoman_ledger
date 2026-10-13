from typing import Optional
from datetime import datetime
from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session, joinedload
import io

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.record import Record

router = APIRouter(prefix="/export", tags=["导出"])


@router.get("/csv")
def export_csv(
    month: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    q = (
        db.query(Record)
        .options(joinedload(Record.category))
        .filter(Record.user_id == user.id)
        .order_by(Record.date.desc())
    )
    if month:
        q = q.filter(Record.date.startswith(month))

    records = q.all()

    output = io.StringIO()
    output.write("﻿日期,类型,分类,金额,备注\n")
    for r in records:
        type_name = r.type.value if hasattr(r.type, 'value') else r.type
        cat_name = r.category.name if r.category else ""
        note = r.note or ""
        # 防止 CSV 注入：转义特殊字符
        note = note.replace('"', '""')
        cat_name = cat_name.replace('"', '""')
        if any(note.startswith(c) for c in ('=', '+', '-', '@', '\t', '\r')):
            note = f"'{note}"
        output.write(f'{r.date},{type_name},"{cat_name}",{r.amount},"{note}"\n')

    csv_content = output.getvalue()
    output.close()

    return StreamingResponse(
        iter([csv_content]),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": "attachment; filename=records.csv"},
    )


@router.get("/json")
def export_json(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    q = (
        db.query(Record)
        .options(joinedload(Record.category))
        .filter(Record.user_id == user.id)
        .order_by(Record.date.desc())
    )
    records = q.all()
    data = [
        {
            "type": r.type.value if hasattr(r.type, 'value') else r.type,
            "amount": r.amount,
            "category": r.category.name if r.category else "",
            "date": r.date,
            "note": r.note,
        }
        for r in records
    ]
    import json
    json_str = json.dumps(data, ensure_ascii=False, indent=2)
    return StreamingResponse(
        iter([json_str]),
        media_type="application/json",
        headers={"Content-Disposition": "attachment; filename=records.json"},
    )


@router.get("/pdf")
def export_pdf(
    month: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    from reportlab.pdfgen import canvas
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont

    q = (
        db.query(Record)
        .options(joinedload(Record.category))
        .filter(Record.user_id == user.id)
        .order_by(Record.date.desc())
    )
    if month:
        q = q.filter(Record.date.startswith(month))
    records = q.all()

    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)
    w, h = A4
    y = h - 40

    c.setFont("Helvetica-Bold", 16)
    c.drawString(40, y, f"小满记账 - 账单报表")
    y -= 30
    c.setFont("Helvetica", 10)
    c.drawString(40, y, f"导出时间: {datetime.now().strftime('%Y-%m-%d %H:%M')}  共 {len(records)} 条")
    y -= 20

    c.setFont("Helvetica", 9)
    for r in records:
        if y < 60:
            c.showPage()
            y = h - 40
        cat = r.category.name if r.category else ""
        type_label = {"income": "+", "expense": "-", "savings": "◎"}.get(
            r.type.value if hasattr(r.type, 'value') else r.type, ""
        )
        line = f"{r.date}  {type_label}  {cat:10s}  ¥{r.amount:>10.2f}  {r.note or ''}"
        c.drawString(40, y, line)
        y -= 16

    c.save()
    buf.seek(0)

    return StreamingResponse(
        buf,
        media_type="application/pdf",
        headers={"Content-Disposition": "attachment; filename=records.pdf"},
    )
