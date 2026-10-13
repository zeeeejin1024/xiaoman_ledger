from __future__ import annotations

from dataclasses import dataclass
from collections import defaultdict
from statistics import median


@dataclass(frozen=True)
class InsightFact:
    id: str
    kind: str
    values: dict


@dataclass(frozen=True)
class ReportInsights:
    period: str
    data_sufficient: bool
    facts: tuple[InsightFact, ...]
    recommendations: tuple[dict, ...]

    def as_dict(self):
        return {
            "period": self.period,
            "data_sufficient": self.data_sufficient,
            "facts": [{"id": f.id, "kind": f.kind, "values": f.values} for f in self.facts],
            "recommendations": list(self.recommendations),
        }


def _value(record, name, default=None):
    return record.get(name, default) if isinstance(record, dict) else getattr(record, name, default)


class ReportInsightEngine:
    def weekly(self, records, baseline=()):
        return self._build("weekly", records, baseline)

    def monthly(self, records, baseline=()):
        return self._build("monthly", records, baseline)

    def _build(self, period, records, baseline):
        expenses = [r for r in records if str(getattr(_value(r, "type", "expense"), "value", _value(r, "type", "expense"))) == "expense"]
        baseline_expenses = [r for r in baseline if str(getattr(_value(r, "type", "expense"), "value", _value(r, "type", "expense"))) == "expense"]
        total = round(sum(float(_value(r, "amount", 0)) for r in expenses), 2)
        days = {_value(r, "date", "") for r in expenses}
        sufficient = len(expenses) >= 5 and len(days) >= 3
        facts = [InsightFact(f"{period}-total", "total", {"amount": total, "count": len(expenses), "active_days": len(days)})]

        category_totals = defaultdict(float)
        for record in expenses:
            category = _value(record, "category")
            name = getattr(category, "name", None) or _value(record, "category_name", "其他") or "其他"
            category_totals[name] += float(_value(record, "amount", 0))
        if category_totals:
            top_name, top_amount = max(category_totals.items(), key=lambda item: item[1])
            share = round(top_amount / total * 100, 1) if total else 0
            facts.append(InsightFact(f"{period}-top-category", "top_category", {"name": top_name, "amount": round(top_amount, 2), "share_pct": share}))

        baseline_categories = defaultdict(float)
        for record in baseline_expenses:
            category = _value(record, "category")
            name = getattr(category, "name", None) or _value(record, "category_name", "其他") or "其他"
            baseline_categories[name] += float(_value(record, "amount", 0))

        positive_changes = {
            name: amount - baseline_categories.get(name, 0)
            for name, amount in category_totals.items()
            if amount - baseline_categories.get(name, 0) > 0
        }
        growth_total = sum(positive_changes.values())
        strongest_change = None
        if growth_total > 0:
            name, change_amount = max(positive_changes.items(), key=lambda item: item[1])
            baseline_amount = baseline_categories.get(name, 0)
            change_pct = round(change_amount / baseline_amount * 100, 1) if baseline_amount else None
            strongest_change = InsightFact(
                f"{period}-category-change-{name}",
                "category_change",
                {
                    "name": name,
                    "current": round(category_totals[name], 2),
                    "baseline": round(baseline_amount, 2),
                    "change_amount": round(change_amount, 2),
                    "change_pct": change_pct,
                    "contribution_pct": round(change_amount / growth_total * 100, 1),
                },
            )
            facts.append(strongest_change)

        baseline_total = round(sum(float(_value(r, "amount", 0)) for r in baseline_expenses), 2)
        if baseline_total > 0:
            change = round((total - baseline_total) / baseline_total * 100, 1)
            facts.append(InsightFact(f"{period}-change", "period_change", {"current": total, "baseline": baseline_total, "change_pct": change}))

        stable = baseline_total > 0 and abs(total - baseline_total) / baseline_total <= .08
        if stable:
            facts.append(InsightFact(f"{period}-stable", "stable_period", {"current": total, "baseline": baseline_total, "change_pct": round((total - baseline_total) / baseline_total * 100, 1)}))

        amounts = [float(_value(record, "amount", 0)) for record in expenses]
        if len(amounts) >= 8:
            center = median(amounts)
            mad = median(abs(value - center) for value in amounts)
            if mad > 0:
                outliers = [value for value in amounts if .6745 * (value - center) / mad >= 3.5]
                if outliers:
                    facts.append(InsightFact(f"{period}-outlier", "large_outlier", {"amount": round(max(outliers), 2), "median": round(center, 2)}))

        recommendations = []
        if sufficient and stable:
            stable_fact = next(f for f in facts if f.kind == "stable_period")
            recommendations.append({
                "fact_id": stable_fact.id,
                "title": "本期节奏稳定",
                "message": f"本期支出与基线相差 {abs(stable_fact.values['change_pct'])}% ，没有需要刻意压缩的项目。",
                "potential_save": None,
            })
        elif sufficient and strongest_change is not None and strongest_change.values["contribution_pct"] >= 25:
            values = strongest_change.values
            recommendations.append({
                "fact_id": strongest_change.id,
                "title": f"{values['name']}推动了本期变化",
                "message": f"{values['name']}比基线多支出 ¥{values['change_amount']:.2f}，贡献了支出增长的 {values['contribution_pct']}%。",
                "potential_save": None,
            })
        elif sufficient and len(facts) > 1:
            top = facts[1]
            if top.values["share_pct"] >= 35:
                saving = round(top.values["amount"] * .1, 2)
                recommendations.append({
                    "fact_id": top.id,
                    "title": f"留意{top.values['name']}支出",
                    "message": f"该分类占本期支出的 {top.values['share_pct']}%，下期先尝试减少约 ¥{saving:.2f}。",
                    "potential_save": saving,
                })
        return ReportInsights(period, sufficient, tuple(facts), tuple(recommendations))
