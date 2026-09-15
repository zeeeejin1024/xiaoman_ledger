# 分类选择与钱包规则实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 允许每笔账单只选大类或继续选子类，并让钱包按一个或多个分类及其后代实时汇总。

**Architecture:** `CategorySelection` 作为前端统一选择结果；服务端用 `WalletCategoryBinding` 表达钱包与分类的多对多规则。聚合逻辑只按分类树计算，不依赖分类名称。

**Tech Stack:** Flutter 3、Dart、FastAPI、SQLAlchemy 2、SQLite/MySQL、pytest、flutter_test。

---

## File Structure

- Create: `backend/app/models/wallet_category_binding.py`
- Create: `backend/app/services/wallet_service.py`
- Create: `backend/tests/test_wallet_service.py`
- Modify: `backend/app/models/wallet_budget.py`
- Modify: `backend/app/api/wallets.py`
- Create: `frontend/lib/data/models/category_selection.dart`
- Create: `frontend/lib/data/models/wallet_budget.dart`
- Create: `frontend/lib/data/api/wallet_api.dart`
- Create: `frontend/lib/widgets/category_selector.dart`
- Create: `frontend/test/widgets/category_selector_test.dart`
- Create: `frontend/test/modules/wallet/wallet_rules_test.dart`
- Modify: `frontend/lib/modules/record/add_record_sheet.dart`
- Modify: `frontend/lib/modules/wallet/wallet_page.dart`
- Modify: `frontend/pubspec.yaml`
- Modify: `frontend/lib/core/constants.dart`
- Modify: `frontend/test/core/version_test.dart`

### Task 1: Define category selection semantics

- [ ] **Step 1: Write the failing widget tests**

```dart
testWidgets('a root category can be selected without choosing a child', (tester) async {
  CategorySelection? value;
  await tester.pumpWidget(testApp(CategorySelector(
    categories: expenseCategories,
    value: null,
    onChanged: (next) => value = next,
  )));
  await tester.tap(find.text('餐饮'));
  await tester.pump();
  expect(value, const CategorySelection(
    categoryId: 1,
    parentCategoryId: 1,
    specificity: CategorySpecificity.parent,
    source: CategorySelectionSource.user,
    confidence: 1,
  ));
});
```

- [ ] **Step 2: Run and verify RED**

Run: `flutter test test/widgets/category_selector_test.dart`

Expected: FAIL because `CategorySelection` and `CategorySelector` do not exist.

- [ ] **Step 3: Implement the value type and selector**

```dart
enum CategorySpecificity { parent, leaf }
enum CategorySelectionSource { user, merchantRule, parser, vision }

class CategorySelection {
  final int categoryId;
  final int parentCategoryId;
  final CategorySpecificity specificity;
  final CategorySelectionSource source;
  final double confidence;
  const CategorySelection({
    required this.categoryId,
    required this.parentCategoryId,
    required this.specificity,
    required this.source,
    required this.confidence,
  });
}
```

`CategorySelector` 第一层点击直接选中大类，独立展开按钮显示子类；不得用点击大类同时展开的二义性交互。

- [ ] **Step 4: Reuse it in manual entry and verify GREEN**

Run: `flutter test test/widgets/category_selector_test.dart`

Expected: PASS, including “无分类时保存按钮不可用”和“大类 ID 原样提交”。

- [ ] **Step 5: Commit**

```powershell
git add frontend/lib/data/models/category_selection.dart frontend/lib/widgets/category_selector.dart frontend/lib/modules/record/add_record_sheet.dart frontend/test/widgets/category_selector_test.dart
git commit -m "feat: allow parent category selection"
```

### Task 2: Add wallet binding persistence and aggregation

- [ ] **Step 1: Write failing service tests**

```python
def test_parent_binding_includes_descendants(session, food_wallet, categories, records):
    bind(session, food_wallet.id, category_id=1, include_descendants=True)
    result = calculate_wallet_spend(session, user_id=1, month="2026-09")
    assert result[food_wallet.id] == 57.0  # 早餐 12 + 午餐 20 + 晚餐 25

def test_leaf_binding_beats_parent_binding(session, food_wallet, lunch_wallet, records):
    bind(session, food_wallet.id, 1, True)
    bind(session, lunch_wallet.id, 3, False)
    result = calculate_wallet_spend(session, 1, "2026-09")
    assert result[lunch_wallet.id] == 20.0
    assert result[food_wallet.id] == 37.0
```

- [ ] **Step 2: Run and verify RED**

Run: `python -m pytest backend/tests/test_wallet_service.py -q`

Expected: FAIL because binding model/service are absent.

- [ ] **Step 3: Add binding model and deterministic matcher**

```python
class WalletCategoryBinding(Base):
    __tablename__ = "wallet_category_bindings"
    id: Mapped[int] = mapped_column(primary_key=True)
    wallet_id: Mapped[int] = mapped_column(ForeignKey("wallet_budgets.id"), index=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"), index=True)
    include_descendants: Mapped[bool] = mapped_column(Boolean, default=False)
```

`calculate_wallet_spend` 先建立 `category_id -> ancestor_ids`，再按“精确子类、钱包排序、大类后代”的顺序匹配，每笔支出最多进入一个消费钱包。

- [ ] **Step 4: Replace name-based wallet API aggregation**

`GET /wallets` 返回：

```json
{"id":1,"name":"一日三餐","amount":1500,"bindings":[{"category_id":1,"include_descendants":true}],"spent":57,"remaining":1443}
```

Run: `python -m pytest backend/tests/test_wallet_service.py -q`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add backend/app/models backend/app/services/wallet_service.py backend/app/api/wallets.py backend/tests/test_wallet_service.py
git commit -m "feat: aggregate wallets by category bindings"
```

### Task 3: Migrate legacy local budgets

- [ ] **Step 1: Test one-time migration**

```dart
test('legacy category budgets become one-binding wallets without amount loss', () async {
  SharedPreferences.setMockInitialValues({'wallet_budget_3': 600.0});
  final migrated = await migrator.run(categories);
  expect(migrated.single.monthlyLimit, 600);
  expect(migrated.single.bindings.single.categoryId, 3);
  expect(migrated.single.bindings.single.includeDescendants, isFalse);
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/modules/wallet/wallet_rules_test.dart`

Expected: FAIL because migrator is absent.

- [ ] **Step 3: Implement upload-then-mark migration**

Only set `wallet_rules_migrated_v1=true` after the server accepts all wallets. On failure retain legacy keys and retry next launch.

- [ ] **Step 4: Verify frontend and backend suites**

Run: `flutter test test/widgets/category_selector_test.dart test/modules/wallet/wallet_rules_test.dart`

Run: `python -m pytest backend/tests/test_wallet_service.py -q`

Expected: all PASS.

- [ ] **Step 5: Release as `6.1.0+20`**

Update both version sources and run `flutter test test/core/version_test.dart`; build, inspect APK metadata/signature, record SHA-256, then cover-install on Android 16 without clearing data.
