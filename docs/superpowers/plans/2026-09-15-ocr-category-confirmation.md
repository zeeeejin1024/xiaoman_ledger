# 截图记账分类确认实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让截图识别结果可选择大类/子类、批量修改并逐笔确认，同时学习稳定的个人商家分类习惯。

**Architecture:** OCR 只产出候选事实和置信度；统一确认页拥有最终决定权。服务端以用户隔离的商家规则和图片哈希缓存降低模型调用，不再回退默认分类。

**Tech Stack:** Flutter、Dio、FastAPI、SQLAlchemy、Qwen VL、SHA-256、pytest、flutter_test。

---

## File Structure

- Create: `backend/app/models/merchant_category_rule.py`
- Create: `backend/app/models/ocr_cache.py`
- Create: `backend/app/services/ocr_pipeline.py`
- Create: `backend/tests/test_ocr_pipeline.py`
- Modify: `backend/app/api/ocr.py`
- Modify: `backend/app/services/llm_parser.py`
- Create: `frontend/lib/modules/ocr/ocr_result_page.dart`
- Create: `frontend/lib/modules/ocr/ocr_result_controller.dart`
- Create: `frontend/test/modules/ocr/ocr_result_page_test.dart`
- Modify: `frontend/lib/modules/home/home_page.dart`

### Task 1: Stop silent category fallback

- [ ] **Step 1: Add failing backend tests**

```python
def test_unknown_category_stays_unselected(db):
    result = resolve_category(db, "不存在的分类")
    assert result.category_id is None
    assert result.confidence == 0

def test_root_category_can_be_resolved(db):
    result = resolve_category(db, "餐饮")
    assert result.category_id == 1
    assert result.specificity == "parent"
```

- [ ] **Step 2: Run RED**

Run: `python -m pytest backend/tests/test_ocr_pipeline.py -q`

Expected: unknown currently falls back and root categories are filtered out.

- [ ] **Step 3: Implement typed OCR candidates**

```python
class CategoryCandidate(BaseModel):
    category_id: int | None
    category_name: str | None
    parent_category_id: int | None
    specificity: Literal["parent", "leaf"] | None
    source: Literal["merchant_rule", "vision", "none"]
    confidence: float
```

Prompt receives both root and leaf categories. `_match_category` returns `None`, never `db_categories[0]`.

- [ ] **Step 4: Verify GREEN and commit**

Run: `python -m pytest backend/tests/test_ocr_pipeline.py -q`

```powershell
git add backend/app/api/ocr.py backend/app/services/llm_parser.py backend/app/services/ocr_pipeline.py backend/tests/test_ocr_pipeline.py
git commit -m "fix: keep uncertain OCR categories unselected"
```

### Task 2: Build the editable confirmation page

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('user can assign one parent category to selected OCR rows', (tester) async {
  await tester.pumpWidget(testOcrPage(twoUnknownItems));
  await tester.tap(find.byKey(const ValueKey('ocr-select-all')));
  await tester.tap(find.byKey(const ValueKey('ocr-batch-category')));
  await tester.tap(find.text('餐饮'));
  expect(controller.items.every((e) => e.categoryId == 1), isTrue);
});

testWidgets('save stays disabled while any valid row has no category', (tester) async {
  await tester.pumpWidget(testOcrPage(oneUnknownItem));
  expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('ocr-save'))).onPressed, isNull);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/modules/ocr/ocr_result_page_test.dart`

Expected: FAIL because dedicated OCR page is absent.

- [ ] **Step 3: Implement controller and page**

Each row edits amount, merchant, date, note and `CategorySelection`. Batch category applies only to checked rows. Invalid amount and missing category show inline errors; model output never saves automatically.

- [ ] **Step 4: Replace `_showOcrBatchResult` in home**

Navigate to `OcrResultPage`, pass normalized candidates, and reload home only after `allSaved` outcome.

- [ ] **Step 5: Run GREEN and commit**

Run: `flutter test test/modules/ocr/ocr_result_page_test.dart`

```powershell
git add frontend/lib/modules/ocr frontend/lib/modules/home/home_page.dart frontend/test/modules/ocr
git commit -m "feat: confirm OCR categories before saving"
```

### Task 3: Add merchant learning and image cache

- [ ] **Step 1: Test two-confirmation activation and user isolation**

```python
def test_rule_activates_after_two_equal_confirmations(db):
    learn(db, user_id=1, merchant="瑞幸咖啡", category_id=7)
    assert lookup(db, 1, "瑞幸咖啡") is None
    learn(db, user_id=1, merchant="瑞幸咖啡", category_id=7)
    assert lookup(db, 1, "瑞幸咖啡").category_id == 7
    assert lookup(db, 2, "瑞幸咖啡") is None
```

- [ ] **Step 2: Implement normalized merchant keys and 24-hour OCR cache**

Cache key is `sha256(user_id + decoded_image_bytes)`; cache only parsed candidates, never authentication data. Confirmation endpoint updates the merchant rule after records save successfully.

- [ ] **Step 3: Test partial failure behavior**

`POST /records/batch` returns one result per client item ID. The UI removes successful rows and keeps failed rows with server messages.

- [ ] **Step 4: Verify suites and release `6.2.0+21`**

Run: `python -m pytest backend/tests/test_ocr_pipeline.py -q`

Run: `flutter test test/modules/ocr/ocr_result_page_test.dart`

Update version sources, build/sign/hash APK, cover-install and verify camera/gallery, category correction and partial retry on Android 16.
