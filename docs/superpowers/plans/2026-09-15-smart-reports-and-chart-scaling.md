# 智能报告与统计图缩放实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用确定性事实生成可信周报/月报，并在金额差距过大时提高小柱的可见性但不篡改真实金额。

**Architecture:** `ReportInsightEngine` 只计算事实，`ReportNarrator` 只组织表达且必须引用事实 ID。图表缩放为纯函数，视觉值与真实值分离。

**Tech Stack:** Python、FastAPI、SQLAlchemy、Flutter、fl_chart、pytest、flutter_test。

---

## File Structure

- Create: `backend/app/services/report_insight_engine.py`
- Create: `backend/app/services/report_narrator.py`
- Create: `backend/app/models/report_cache.py`
- Create: `backend/tests/test_report_insight_engine.py`
- Modify: `backend/app/api/reports.py`
- Modify: `backend/app/services/stats_service.py`
- Create: `frontend/lib/modules/stats/chart_scale.dart`
- Create: `frontend/test/modules/stats/chart_scale_test.dart`
- Modify: `frontend/lib/modules/stats/stats_page.dart`
- Modify: `frontend/lib/modules/report/weekly_report_page.dart`
- Modify: `frontend/lib/modules/report/monthly_report_page.dart`

### Task 1: Compute facts without a language model

- [ ] **Step 1: Write RED tests for evidence and sufficiency**

```python
def test_sparse_period_has_no_strong_recommendation(records):
    report = ReportInsightEngine().weekly(records[:4], baseline=records)
    assert report.data_sufficient is False
    assert report.recommendations == []

def test_category_change_references_exact_fact(records):
    report = ReportInsightEngine().weekly(records, baseline=previous_four_weeks())
    fact = next(f for f in report.facts if f.kind == "category_change")
    assert fact.values == {"current": 138.0, "baseline": 100.0, "change_pct": 38.0}
```

- [ ] **Step 2: Run RED**

Run: `python -m pytest backend/tests/test_report_insight_engine.py -q`

Expected: FAIL because insight engine does not exist.

- [ ] **Step 3: Implement immutable facts**

```python
@dataclass(frozen=True)
class InsightFact:
    id: str
    kind: str
    values: dict[str, Decimal | int | str]

@dataclass(frozen=True)
class ReportInsights:
    period: str
    data_sufficient: bool
    facts: tuple[InsightFact, ...]
    recommendations: tuple[Recommendation, ...]
```

Calculate totals, category shares, four-week/three-month baselines, budget deviation, repeated spending, no-spend days and outliers. Estimated savings are calculated from facts, never by the narrator.

- [ ] **Step 4: Verify GREEN and commit**

Run: `python -m pytest backend/tests/test_report_insight_engine.py -q`

```powershell
git add backend/app/services/report_insight_engine.py backend/tests/test_report_insight_engine.py backend/app/services/stats_service.py
git commit -m "feat: calculate evidence-backed report insights"
```

### Task 2: Add constrained narration and cache

- [ ] **Step 1: Test narration cannot introduce values**

```python
def test_narrator_rejects_unknown_amount(fake_model):
    fake_model.reply = '{"fact_id":"food-rise","text":"可省 999 元"}'
    result = ReportNarrator(fake_model).narrate(insights)
    assert result[0].text == deterministic_fallback("food-rise", insights)
```

- [ ] **Step 2: Implement fact-referenced output**

Narrator input contains only fact IDs and aggregated values. Parse model output as JSON; reject missing fact IDs, changed numbers and more than three recommendations. Format each accepted recommendation as “发现、影响、下一步”。

- [ ] **Step 3: Cache by data version**

Cache key is `user_id + report_type + period + max_record_updated_at + record_count`. A new/edited/deleted record changes the key; raw records are not stored in the cache payload.

- [ ] **Step 4: Replace report endpoints and pages**

Both pages render `data_sufficient`, `facts` and `recommendations`. Remove monthly `_suggestionText`; weekly no longer expects `suggestions` from `/stats/weekly`.

- [ ] **Step 5: Verify and commit**

Run: `python -m pytest backend/tests/test_report_insight_engine.py -q`

```powershell
git add backend/app/services/report_narrator.py backend/app/models/report_cache.py backend/app/api/reports.py frontend/lib/modules/report
git commit -m "feat: narrate and cache smart reports"
```

### Task 3: Separate chart display values from true values

- [ ] **Step 1: Write RED scale tests**

```dart
test('uses linear scale when ratio is at most eight', () {
  expect(ChartScale.from([80, 10]).mode, ChartScaleMode.linear);
});

test('uses square-root visual values above ratio eight', () {
  final scale = ChartScale.from([10000, 100]);
  expect(scale.mode, ChartScaleMode.squareRoot);
  expect(scale.visualValue(100), closeTo(0.1, 0.001));
  expect(scale.trueValue(1), 100);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/modules/stats/chart_scale_test.dart`

Expected: FAIL because `ChartScale` is absent.

- [ ] **Step 3: Implement scale and tooltip mapping**

```dart
double visualValue(double value) => mode == ChartScaleMode.linear
    ? value / maxValue
    : math.sqrt(value / maxValue);
```

`BarChartRodData.toY` receives display value; `rodStackItems` or an index map retains the true amount for tooltip and semantics. Show “已优化显示比例” only in square-root mode.

- [ ] **Step 4: Verify and release `6.5.0+24`**

Run: `flutter test test/modules/stats/chart_scale_test.dart`

Run full backend/Flutter suites, update versions, build/sign/hash and verify small columns remain visible while tooltips show exact amounts on Android 16.
