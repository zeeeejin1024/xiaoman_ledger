# 记账成功返回首页与防重复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 所有记账入口只在保存成功后回到首页，并用幂等键阻止二次记账。

**Architecture:** 前端以 `RecordSaveOutcome` 统一单笔/批量结果，以 `RecordNavigationCoordinator` 决定关闭弹层或清理路由。服务端用独立幂等请求表保证重试不会新增记录。

**Tech Stack:** Flutter Navigator、FastAPI、SQLAlchemy、UUID、pytest、flutter_test。

---

## File Structure

- Create: `backend/app/models/idempotency_request.py`
- Create: `backend/app/services/record_writer.py`
- Create: `backend/tests/test_record_idempotency.py`
- Modify: `backend/app/api/records.py`
- Modify: `backend/app/schemas/record.py`
- Create: `frontend/lib/core/record_save_outcome.dart`
- Create: `frontend/lib/core/record_navigation_coordinator.dart`
- Create: `frontend/test/core/record_navigation_coordinator_test.dart`
- Modify: `frontend/lib/data/api/record_api.dart`
- Modify: `frontend/lib/modules/record/add_record_sheet.dart`
- Modify: `frontend/lib/modules/ocr/ocr_result_page.dart`
- Modify: `frontend/lib/modules/voice/voice_page.dart`

### Task 1: Make record creation idempotent

- [ ] **Step 1: Write failing API/service tests**

```python
def test_same_user_and_request_key_creates_one_record(db):
    first = create_record(db, user_id=1, request_id="abc", payload=expense())
    second = create_record(db, user_id=1, request_id="abc", payload=expense())
    assert first.record_id == second.record_id
    assert db.query(Record).count() == 1

def test_request_key_is_scoped_by_user(db):
    assert create_record(db, 1, "abc", expense()).record_id != create_record(db, 2, "abc", expense()).record_id
```

- [ ] **Step 2: Run RED**

Run: `python -m pytest backend/tests/test_record_idempotency.py -q`

Expected: FAIL because request keys are not persisted.

- [ ] **Step 3: Add request ledger**

```python
class IdempotencyRequest(Base):
    __tablename__ = "idempotency_requests"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(index=True)
    request_id: Mapped[str] = mapped_column(String(64))
    response_json: Mapped[str] = mapped_column(Text)
    __table_args__ = (UniqueConstraint("user_id", "request_id"),)
```

Create record and response ledger in one transaction. A duplicate reads and returns stored response.

- [ ] **Step 4: Verify GREEN and commit**

Run: `python -m pytest backend/tests/test_record_idempotency.py -q`

```powershell
git add backend/app/models/idempotency_request.py backend/app/services/record_writer.py backend/app/api/records.py backend/app/schemas/record.py backend/tests/test_record_idempotency.py
git commit -m "feat: make record creation idempotent"
```

### Task 2: Define explicit frontend outcomes

- [ ] **Step 1: Write navigation RED tests**

```dart
testWidgets('successful routed save removes entry routes and returns home', (tester) async {
  await tester.pumpWidget(testRouterAtVoice());
  await coordinator.handle(context, const RecordSaveOutcome.allSaved());
  expect(find.byType(HomePage), findsOneWidget);
  expect(find.byType(VoicePage), findsNothing);
});

testWidgets('partial batch failure stays and retains only failed rows', (tester) async {
  final outcome = RecordSaveOutcome.partial(failedClientIds: const ['b']);
  await coordinator.handle(context, outcome);
  expect(controller.items.map((e) => e.clientId), ['b']);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/core/record_navigation_coordinator_test.dart`

Expected: FAIL because outcome/coordinator do not exist.

- [ ] **Step 3: Implement navigation policy**

```dart
sealed class RecordSaveOutcome {
  const RecordSaveOutcome();
  const factory RecordSaveOutcome.allSaved() = AllRecordsSaved;
  const factory RecordSaveOutcome.partial({required List<String> failedClientIds}) = PartialRecordsSaved;
  const factory RecordSaveOutcome.failed(String message) = RecordSaveFailed;
}
```

Home sheet calls `Navigator.pop` only. Routed entry calls `Navigator.pushNamedAndRemoveUntil(AppRouter.home, (_) => false)`. Partial/failed outcomes never navigate.

- [ ] **Step 4: Add one request ID per user action**

Generate UUID when the user begins a save; retries reuse it until payload changes or succeeds. Buttons remain disabled while awaiting response.

- [ ] **Step 5: Verify all entry points**

Run: `flutter test test/core/record_navigation_coordinator_test.dart test/modules/ocr/ocr_result_page_test.dart test/modules/voice/voice_page_test.dart`

Expected: manual, OCR and voice paths pass without duplicate API calls.

- [ ] **Step 6: Release `6.4.0+23`**

Update versions, build/sign/hash and cover-install. On Android 16 double-tap each save button and verify one new record plus immediate return to home only after success.
