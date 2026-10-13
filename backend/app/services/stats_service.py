from __future__ import annotations

from typing import Dict, List
from sqlalchemy.orm import Session, joinedload
from app.models.record import Record
from app.services.report_insight_engine import ReportInsightEngine


def previous_month(month: str) -> str:
    year, month_number = (int(part) for part in month.split("-", 1))
    if month_number == 1:
        return f"{year - 1}-12"
    return f"{year}-{month_number - 1:02d}"


def get_weekly_stats(db: Session, user_id: int, start_date: str, end_date: str) -> dict:
    """获取周统计数据，包括每日明细"""
    records = (
        db.query(Record)
        .options(joinedload(Record.category))
        .filter(Record.user_id == user_id)
        .filter(Record.date >= start_date)
        .filter(Record.date <= end_date)
        .all()
    )

    # 按日分组
    daily_data: Dict[str, dict] = {}
    for r in records:
        day = r.date
        if day not in daily_data:
            daily_data[day] = {"income": 0.0, "expense": 0.0}
        type_name = r.type.value if hasattr(r.type, 'value') else r.type
        if type_name == "income":
            daily_data[day]["income"] += r.amount
        elif type_name == "expense":
            daily_data[day]["expense"] += r.amount

    # 转换为列表
    daily_list = []
    for day in sorted(daily_data.keys()):
        d = daily_data[day]
        daily_list.append({
            "date": day,
            "income": round(d["income"], 2),
            "expense": round(d["expense"], 2),
        })

    total_expense = sum(d["expense"] for d in daily_list)
    total_income = sum(d["income"] for d in daily_list)

    # 上周同期数据
    from datetime import datetime, timedelta
    try:
        end_dt = datetime.strptime(end_date, "%Y-%m-%d")
        start_dt = datetime.strptime(start_date, "%Y-%m-%d")
        last_week_end = start_dt - timedelta(days=1)
        last_week_start = last_week_end - timedelta(days=6)
        last_start_str = last_week_start.strftime("%Y-%m-%d")
        last_end_str = last_week_end.strftime("%Y-%m-%d")

        last_records = (
            db.query(Record)
            .filter(Record.user_id == user_id)
            .filter(Record.date >= last_start_str)
            .filter(Record.date <= last_end_str)
            .all()
        )
        last_week_expense = sum(r.amount for r in last_records if (r.type.value if hasattr(r.type, 'value') else r.type) == "expense")
    except:
        last_week_expense = 0

    insights = ReportInsightEngine().weekly(records, last_records if 'last_records' in locals() else [])
    return {
        "daily": daily_list,
        "total_expense": round(total_expense, 2),
        "total_income": round(total_income, 2),
        "last_week_expense": round(last_week_expense, 2),
        "start_date": start_date,
        "end_date": end_date,
        "insights": insights.as_dict(),
        "suggestions": [item["message"] for item in insights.recommendations],
    }


def get_monthly_stats(db: Session, user_id: int, month: str) -> dict:
    records = (
        db.query(Record)
        .options(joinedload(Record.category))
        .filter(Record.user_id == user_id)
        .filter(Record.date.startswith(month))
        .all()
    )
    baseline = (
        db.query(Record)
        .options(joinedload(Record.category))
        .filter(Record.user_id == user_id)
        .filter(Record.date.startswith(previous_month(month)))
        .all()
    )
    return _aggregate(records, baseline)


def get_yearly_stats(db: Session, user_id: int, year: str) -> dict:
    records = (
        db.query(Record)
        .options(joinedload(Record.category))
        .filter(Record.user_id == user_id)
        .filter(Record.date.startswith(year))
        .all()
    )

    # 按月分组
    months_data: Dict[str, dict] = {}
    for r in records:
        m = r.date[:7]
        if m not in months_data:
            months_data[m] = {"income": 0.0, "expense": 0.0, "savings": 0.0}
        type_name = r.type.value if hasattr(r.type, 'value') else r.type
        if type_name in months_data[m]:
            months_data[m][type_name] += r.amount

    months_list = []
    for m in sorted(months_data.keys()):
        d = months_data[m]
        months_list.append({
            "month": m,
            "income": round(d["income"], 2),
            "expense": round(d["expense"], 2),
            "savings": round(d["savings"], 2),
            "balance": round(d["income"] - d["expense"] - d["savings"], 2),
        })

    total_income = sum(x["income"] for x in months_list)
    total_expense = sum(x["expense"] for x in months_list)
    total_savings = sum(x["savings"] for x in months_list)

    return {
        "year": year,
        "months": months_list,
        "total_income": round(total_income, 2),
        "total_expense": round(total_expense, 2),
        "total_savings": round(total_savings, 2),
        "total_balance": round(total_income - total_expense - total_savings, 2),
    }


def _aggregate(records: List[Record], baseline: List[Record] | tuple = ()) -> dict:
    income = 0.0
    expense = 0.0
    savings = 0.0
    income_cats: Dict[str, float] = {}
    expense_cats: Dict[str, float] = {}
    savings_cats: Dict[str, float] = {}
    cat_emojis: Dict[str, str] = {}

    for r in records:
        type_name = r.type.value if hasattr(r.type, 'value') else r.type
        cat_name = r.category.name if r.category else ""
        cat_emoji = r.category.emoji if r.category and r.category.emoji else ""
        if cat_name and cat_emoji:
            cat_emojis[cat_name] = cat_emoji
        if type_name == "income":
            income += r.amount
            income_cats[cat_name] = income_cats.get(cat_name, 0) + r.amount
        elif type_name == "savings":
            savings += r.amount
            savings_cats[cat_name] = savings_cats.get(cat_name, 0) + r.amount
        else:
            expense += r.amount
            expense_cats[cat_name] = expense_cats.get(cat_name, 0) + r.amount

    insights = ReportInsightEngine().monthly(records, baseline)
    return {
        "income": round(income, 2),
        "expense": round(expense, 2),
        "savings": round(savings, 2),
        "balance": round(income - expense - savings, 2),
        "net_balance": round(income - expense, 2),
        "count": len(records),
        "income_cats": income_cats,
        "expense_cats": expense_cats,
        "savings_cats": savings_cats,
        "cat_emojis": cat_emojis,
        "insights": insights.as_dict(),
        "recommendations": list(insights.recommendations),
    }
