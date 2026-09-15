# 语音记账混合智能实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将文字伪语音升级为真实录音、可纠正转写和低成本混合语义解析。

**Architecture:** Flutter 只负责录音状态与确认；服务端先运行确定性解析和个人规则，只有歧义输入才调用小模型。任何低置信度分类保持未选择，不再静默回退。

**Tech Stack:** Flutter、record、Dio multipart、讯飞听写、FastAPI、规则解析、小模型兜底。

---

## File Structure

- Modify: `frontend/pubspec.yaml`
- Create: `frontend/lib/modules/voice/voice_recorder_controller.dart`
- Create: `frontend/lib/modules/voice/voice_confirmation.dart`
- Modify: `frontend/lib/modules/voice/voice_page.dart`
- Create: `frontend/test/modules/voice/voice_page_test.dart`
- Create: `backend/app/services/hybrid_parser.py`
- Create: `backend/app/services/parser_cost_policy.py`
- Create: `backend/tests/test_hybrid_parser.py`
- Modify: `backend/app/api/ai.py`
- Modify: `backend/app/services/ai_parser.py`

### Task 1: Harden deterministic parsing before recording

- [ ] **Step 1: Add RED cases**

```python
@pytest.mark.parametrize(("text", "expected"), [
    ("午饭二十二块五", [{"type": "expense", "amount": 22.5}]),
    ("退了我三十元", [{"type": "income", "amount": 30.0}]),
    ("不是二十，是十二块", [{"type": "expense", "amount": 12.0}]),
    ("早餐八块，地铁三块", [{"amount": 8.0}, {"amount": 3.0}]),
])
def test_spoken_money_and_multi_record(text, expected):
    assert project(parse_hybrid(text).items) == expected
```

- [ ] **Step 2: Run RED**

Run: `python -m pytest backend/tests/test_hybrid_parser.py -q`

Expected: current parser fails spoken decimals, corrections and multiple records.

- [ ] **Step 3: Implement rule pipeline**

```python
@dataclass
class ParsedItem:
    type: str
    amount: Decimal | None
    category_id: int | None
    confidence: float
    ambiguities: list[str]

def should_call_model(items: list[ParsedItem]) -> bool:
    return len(items) > 1 or any(i.amount is None or i.confidence < 0.78 or i.ambiguities for i in items)
```

Rules handle Chinese numerals, correction words, refund/income terms and sentence splitting. The model receives only transcript plus category names.

- [ ] **Step 4: Verify model bypass**

Add a spy test proving “午餐 22 元” makes zero model calls and ambiguous multi-record input makes one.

- [ ] **Step 5: Commit**

```powershell
git add backend/app/services/hybrid_parser.py backend/app/services/parser_cost_policy.py backend/app/services/ai_parser.py backend/app/api/ai.py backend/tests/test_hybrid_parser.py
git commit -m "feat: add cost-aware voice parser"
```

### Task 2: Add real recording with explicit states

- [ ] **Step 1: Add dependency and failing controller tests**

Use `record: ^6.1.2`. Test states `idle -> recording -> uploading -> confirming`, permission denial, cancel and retry.

```dart
expect(controller.state, VoiceState.idle);
await controller.start();
expect(controller.state, VoiceState.recording);
await controller.stopAndUpload();
expect(controller.state, VoiceState.confirming);
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/modules/voice/voice_page_test.dart`

Expected: FAIL because recorder controller is absent.

- [ ] **Step 3: Implement recorder and multipart upload**

Record mono AAC/M4A using the platform-supported sample rate, show elapsed time, and cap recordings at 45 seconds. Upload with `MultipartFile.fromFile`; cancel deletes only the current temporary audio file.

- [ ] **Step 4: Build unified confirmation UI**

Display editable transcript, one or more parsed items, amount/type/date and shared `CategorySelector`. Disable save for missing amount/category. Failed recognition retains audio and offers “重新识别” and “改用文字”。

- [ ] **Step 5: Verify and commit**

Run: `flutter test test/modules/voice/voice_page_test.dart`

```powershell
git add frontend/pubspec.yaml frontend/lib/modules/voice frontend/test/modules/voice
git commit -m "feat: record and confirm voice entries"
```

### Task 3: Measure cost without harming UX

- [ ] **Step 1: Add structured metrics**

Log parser route (`rule`, `merchant_rule`, `model`), latency bucket, item count and success; do not log raw transcript or audio.

- [ ] **Step 2: Acceptance tests**

Rule-resolvable requests return within 500ms server time; model fallback shows cancellable progress and preserves transcript; repeated confirmed merchant/category combinations bypass category model reasoning.

- [ ] **Step 3: Release `6.3.0+22`**

Run backend and Flutter suites, update both version sources, build/sign/hash APK, then cover-install. On Android 16 verify permission denial, 3-second/45-second recordings, interruption, retry, correction and save-to-home.
