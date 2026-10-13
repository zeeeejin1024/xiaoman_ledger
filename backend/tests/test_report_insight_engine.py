from app.services.report_insight_engine import ReportInsightEngine
from app.services.stats_service import previous_month


def test_sparse_period_has_no_strong_recommendation():
    report = ReportInsightEngine().weekly([{"amount": 10}] * 4)
    assert report.data_sufficient is False
    assert report.recommendations == ()


def test_report_contains_total_fact():
    report = ReportInsightEngine().weekly([{"amount": 10}] * 5)
    assert report.facts[0].values["amount"] == 50


def test_previous_month_handles_year_boundary():
    assert previous_month("2026-09") == "2026-08"
    assert previous_month("2026-01") == "2025-12"


def test_category_change_reports_contribution_to_growth():
    current = [
        {"type": "expense", "amount": 80, "date": "2026-09-01", "category_name": "餐饮"},
        {"type": "expense", "amount": 70, "date": "2026-09-02", "category_name": "餐饮"},
        {"type": "expense", "amount": 20, "date": "2026-09-03", "category_name": "交通"},
        {"type": "expense", "amount": 10, "date": "2026-09-04", "category_name": "购物"},
        {"type": "expense", "amount": 10, "date": "2026-09-05", "category_name": "购物"},
    ]
    baseline = [
        {"type": "expense", "amount": 50, "date": "2026-08-01", "category_name": "餐饮"},
        {"type": "expense", "amount": 20, "date": "2026-08-02", "category_name": "交通"},
    ]
    report = ReportInsightEngine().weekly(current, baseline)
    fact = next(f for f in report.facts if f.kind == "category_change")
    assert fact.values["name"] == "餐饮"
    assert fact.values["contribution_pct"] == 83.3
    assert report.recommendations[0]["fact_id"] == fact.id


def test_stable_period_does_not_invent_savings_advice():
    current = [
        {"type": "expense", "amount": 20, "date": f"2026-09-0{i}", "category_name": "餐饮"}
        for i in range(1, 6)
    ]
    baseline = [
        {"type": "expense", "amount": 20, "date": f"2026-08-0{i}", "category_name": "餐饮"}
        for i in range(1, 6)
    ]
    report = ReportInsightEngine().weekly(current, baseline)
    assert any(f.kind == "stable_period" for f in report.facts)
    assert all(item.get("potential_save") is None for item in report.recommendations)
