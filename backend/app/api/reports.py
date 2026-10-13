from datetime import datetime, timedelta
from typing import List
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.record import Record
from app.models.deal import Deal
from collections import defaultdict
from app.services.stats_service import get_weekly_stats

router = APIRouter(tags=["AI助手"])


# ============================================================
# 省钱周报
# ============================================================
@router.get("/ai/report/weekly", response_model=dict)
def weekly_report(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Generate the same evidence-backed weekly report used by statistics."""
    today = datetime.now().date()
    start = today - timedelta(days=7)
    start_str = start.strftime("%Y-%m-%d")
    end_str = today.strftime("%Y-%m-%d")

    data = get_weekly_stats(db, user.id, start_str, end_str)
    data["has_data"] = data["total_expense"] > 0
    data["period"] = f"{start_str} - {end_str}"
    if not data["has_data"]:
        data["message"] = "本周还没有支出记录"
    return {"code": 0, "data": data}


# ============================================================
# 无用会员检测
# ============================================================
@router.get("/ai/subscriptions", response_model=dict)
def detect_subscriptions(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """扫描固定支出，识别疑似会员/订阅"""
    records = (
        db.query(Record)
        .options(joinedload(Record.category))
        .filter(Record.user_id == user.id, Record.type == "expense")
        .order_by(Record.date.desc())
        .all()
    )

    # 查找相同金额、相同分类且在不同月份出现的记录
    pattern_map = defaultdict(list)
    for r in records:
        if r.note and any(kw in (r.note or "") for kw in ["会员", "VIP", "订阅", "月卡", "季卡", "年卡", "自动续费"]):
            key = f"{r.category.name}|{r.amount}"
            pattern_map[key].append(r)

    subscriptions = []
    member_keywords = ["视频", "音乐", "云盘", "阅读", "加速", "工具", "网盘", "会员", "VIP", "订阅"]
    for key, recs in pattern_map.items():
        if len(recs) >= 2:
            cat_name, amount = key.split("|")
            # 检查是否包含已知会员关键词
            is_member = any(kw in (recs[0].note or "") or kw in cat_name for kw in member_keywords)
            if is_member or len(recs) >= 3:
                last_date = max(r.date for r in recs)
                days_ago = (datetime.now().date() - datetime.strptime(last_date, "%Y-%m-%d").date()).days
                subscriptions.append({
                    "name": cat_name,
                    "amount": float(amount),
                    "last_use_days_ago": days_ago,
                    "occurrences": len(recs),
                    "note": recs[0].note or "",
                    "likely_unused": days_ago > 30,
                    "yearly_cost": float(amount) * 12,
                })

    return {"code": 0, "data": subscriptions}


# ============================================================
# 薅羊毛提醒
# ============================================================
class DealCreate(BaseModel):
    title: str
    description: str = ""
    remind_date: str

@router.get("/deals", response_model=dict)
def get_deals(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """获取近期优惠提醒"""
    # 系统预置 + 用户自定义
    today = datetime.now().strftime("%m-%d")
    system_deals = _get_system_deals(today)
    user_deals = db.query(Deal).filter(Deal.user_id == user.id, Deal.is_done == False).all()
    result = system_deals + [{"title": d.title, "description": d.description, "remind_date": d.remind_date, "id": d.id} for d in user_deals]
    return {"code": 0, "data": sorted(result, key=lambda x: x["remind_date"])}


@router.post("/deals", response_model=dict)
def create_deal(req: DealCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """添加自定义薅羊毛提醒"""
    deal = Deal(user_id=user.id, title=req.title, description=req.description, remind_date=req.remind_date)
    db.add(deal)
    db.commit()
    return {"code": 0, "message": "已添加提醒"}


@router.delete("/deals/{deal_id}", response_model=dict)
def delete_deal(deal_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    deal = db.query(Deal).filter(Deal.id == deal_id, Deal.user_id == user.id).first()
    if deal: db.delete(deal); db.commit()
    return {"code": 0, "message": "已删除"}


MONTHLY_DEALS = {
    "01-01": "元旦特惠：各平台有新年红包活动！",
    "01-20": "支付宝集五福活动即将开始～",
    "02-14": "情人节：各大商家有折扣哦！",
    "03-08": "女神节：化妆品、服饰大促！",
    "04-01": "愚人节：小心被商家套路～",
    "06-18": "618年中大促！别错过！",
    "08-08": "支付宝会员日：积分兑换特权",
    "10-01": "国庆大促：各大平台全面降价",
    "11-11": "双十一！但别冲动消费哦～",
    "12-12": "双十二年终大促最后一波",
    "每月20日": "支付宝会员日：肯德基有半价活动，不要错过哦～",
}


def _get_system_deals(today_mmdd):
    result = []
    for key, msg in MONTHLY_DEALS.items():
        if "每月" in key:
            day = key.replace("每月", "").replace("日", "")
            if today_mmdd.endswith(f"-{day}"):
                result.append({"title": key, "description": msg, "remind_date": datetime.now().strftime("%Y-%m-%d"), "id": -1})
        elif key == today_mmdd:
            result.append({"title": key, "description": msg, "remind_date": datetime.now().strftime("%Y-%m-%d"), "id": -1})
    return result
