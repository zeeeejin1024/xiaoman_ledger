# 通知中心重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用可解释、可恢复的规则与调度状态机替换旧通知设置页面，并在 Android 16 上验证真实定时提醒。

**Architecture:** `NotificationRule -> SchedulePlan -> PlatformScheduler -> AuditState` 四层分离。普通页面只呈现用户决策，测试和系统诊断移入开发诊断页；旧通知仅在新计划确认成功后取消。

**Tech Stack:** Flutter、flutter_local_notifications、timezone、permission_handler、SharedPreferences、Android API 36、flutter_test。

---

## File Structure

- Create: `frontend/lib/modules/notifications/notification_center_page.dart`
- Create: `frontend/lib/modules/notifications/notification_diagnostics_page.dart`
- Create: `frontend/lib/core/notifications/notification_rule.dart`
- Create: `frontend/lib/core/notifications/schedule_plan.dart`
- Create: `frontend/lib/core/notifications/platform_scheduler.dart`
- Create: `frontend/lib/core/notifications/notification_audit.dart`
- Create: `frontend/lib/core/notifications/notification_migrator.dart`
- Create: `frontend/test/core/notifications/notification_state_machine_test.dart`
- Create: `frontend/test/core/notifications/notification_migration_test.dart`
- Create: `frontend/test/modules/notifications/notification_center_page_test.dart`
- Modify: `frontend/lib/modules/settings/settings_page.dart`
- Modify: `frontend/lib/core/notifications.dart`
- Modify: `frontend/lib/core/notification_coordinator.dart`
- Modify: `frontend/android/app/src/main/AndroidManifest.xml`

### Task 1: Define the state machine independently of plugins

- [ ] **Step 1: Write RED policy tests**

```dart
test('enabled rule with permission creates an auditable next occurrence', () {
  final plan = planner.plan(rule: dailyAt(21, 0), now: at(2026, 9, 15, 20, 0), capabilities: allowed);
  expect(plan.nextAt, at(2026, 9, 15, 21, 0));
  expect(plan.audit.state, AuditState.scheduled);
});

test('missing exact alarm permission is blocked, not reported as scheduled', () {
  final plan = planner.plan(rule: dailyAt(21, 0), now: now, capabilities: noExactAlarm);
  expect(plan.audit.state, AuditState.blocked);
  expect(plan.audit.action, AuditAction.openExactAlarmSettings);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/core/notifications/notification_state_machine_test.dart`

Expected: FAIL because the four-layer types do not exist.

- [ ] **Step 3: Implement immutable types**

```dart
enum AuditState { disabled, blocked, scheduled, degraded, failed }

class NotificationRule {
  final String id;
  final bool enabled;
  final TimeOfDay time;
  final NotificationRuleKind kind;
  const NotificationRule({required this.id, required this.enabled, required this.time, required this.kind});
}

class SchedulePlan {
  final DateTime? nextAt;
  final AndroidScheduleMode mode;
  final NotificationAudit audit;
  const SchedulePlan({required this.nextAt, required this.mode, required this.audit});
}
```

Planner is pure Dart and handles passed time, month length, timezone change and unavailable exact alarms.

- [ ] **Step 4: Verify GREEN and commit**

Run: `flutter test test/core/notifications/notification_state_machine_test.dart`

```powershell
git add frontend/lib/core/notifications frontend/test/core/notifications/notification_state_machine_test.dart
git commit -m "feat: model notification scheduling states"
```

### Task 2: Build platform scheduler and recovery

- [ ] **Step 1: Add fake-scheduler tests**

Test permission denied, precise schedule, inexact fallback, plugin exception, pending-request mismatch, reboot/upgrade reconciliation and timezone replan.

- [ ] **Step 2: Implement plugin adapter**

Only `PlatformScheduler` imports `flutter_local_notifications`. After scheduling, immediately query pending requests; return `scheduled` only when the expected ID and time are represented. Store last audit and next occurrence.

- [ ] **Step 3: Add lifecycle reconciliation**

On cold start, app upgrade and timezone change, regenerate plans from rules and reconcile platform requests. Do not request permissions automatically during startup.

- [ ] **Step 4: Verify and commit**

Run: `flutter test test/core/notifications/notification_state_machine_test.dart`

```powershell
git add frontend/lib/core/notifications frontend/lib/core/notification_coordinator.dart frontend/android/app/src/main/AndroidManifest.xml
git commit -m "feat: reconcile Android notification schedules"
```

### Task 3: Migrate safely from legacy preferences and IDs

- [ ] **Step 1: Write RED migration tests**

```dart
test('legacy reminders remain until replacement schedule is verified', () async {
  scheduler.nextResult = AuditState.failed;
  await migrator.run(legacyPrefs);
  verifyNever(() => scheduler.cancelLegacy(any()));
  expect(await prefs.getBool('notification_rules_v2_migrated'), isNot(true));
});
```

- [ ] **Step 2: Implement two-phase migration**

Read legacy daily/weekly/monthly/deal/budget preferences, write v2 rules, schedule and audit all enabled rules, then cancel legacy IDs only if every replacement is scheduled or explicitly degraded. Persist a backup JSON until the next successful launch.

- [ ] **Step 3: Verify GREEN**

Run: `flutter test test/core/notifications/notification_migration_test.dart`

Expected: success cancels legacy IDs once; failure leaves them and permits retry/rollback.

### Task 4: Replace the user page and move diagnostics

- [ ] **Step 1: Write page RED tests**

```dart
testWidgets('user page shows next reminder without test controls', (tester) async {
  await tester.pumpWidget(testCenter(scheduledTomorrowAt2100));
  expect(find.text('下一次提醒：明天 21:00'), findsOneWidget);
  expect(find.textContaining('15秒'), findsNothing);
  expect(find.text('待触发通知'), findsNothing);
});
```

- [ ] **Step 2: Implement ordinary page**

Show permission state, daily reminder, time, weekly/monthly reports, budget threshold, deal reminders and each rule's next occurrence/action. A failed row offers a precise recovery action instead of generic success toast.

- [ ] **Step 3: Implement diagnostics page**

Developer-only page contains immediate test, 15-second test, pending IDs, timezone, exact-alarm capability, last audit and “重新协调”。Hide it behind seven taps on the notification page version label.

- [ ] **Step 4: Remove old notification block only after new tests pass**

Replace the old inline settings section with one “通知” row linking to `NotificationCenterPage`. Keep legacy services only for migration and remove them in a later cleanup release.

- [ ] **Step 5: Verify Flutter suite**

Run: `flutter test test/core/notifications test/modules/notifications/notification_center_page_test.dart`

### Task 5: Android 16 release matrix

- [ ] **Step 1: Release `7.0.0+27`**

Update both version sources, analyze/test/build, inspect APK metadata/signature/hash and cover-install without clearing data.

- [ ] **Step 2: Run real schedules**

Verify permission allow/deny, exact alarm allow/deny, immediate/15-second diagnostics, user-selected next minute, screen off, Doze, process killed, reboot, timezone change and app upgrade. For each case capture expected next time, pending ID, delivered notification and audit state.

- [ ] **Step 3: Pass/fail rule**

No UI may say “已调度” unless the platform queue audit agrees. Missed delivery, duplicated delivery, stale next time, lost rules after upgrade or uncancelled legacy duplicates block release. Preserve an iOS `PlatformScheduler` interface but do not ship iOS behavior in this Android-first release.
