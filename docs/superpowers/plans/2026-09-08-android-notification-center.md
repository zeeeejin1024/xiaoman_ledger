# Android Notification Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a reliable local notification center for Android with iOS-compatible Dart interfaces, covering daily reminders, budget thresholds, weekly/monthly reports, deal reminders, settings, tap routing, and restart reconciliation.

**Architecture:** Keep product rules in a pure Dart `NotificationCoordinator` and `NotificationPolicy` layer. Keep plugin/platform calls inside `NotificationService`; keep persisted settings behind `NotificationPreferencesRepository`; keep API access behind injected loader callbacks. Existing pages call the coordinator at startup and after successful data changes.

**Tech Stack:** Flutter/Dart, `flutter_local_notifications` 18.0.1, `timezone`, SharedPreferences, existing Dio APIs, Flutter widget/unit tests.

---

## Files and responsibilities

- Create `frontend/lib/core/notification_models.dart`: typed preferences, semantic payload, schedule descriptors, budget/deal snapshots.
- Create `frontend/lib/core/notification_preferences.dart`: SharedPreferences repository, defaults, validation, and migration from existing reminder keys.
- Create `frontend/lib/core/notification_policy.dart`: pure date math, IDs, budget dedupe keys, daily/report/deal schedule calculations.
- Create `frontend/lib/core/notification_coordinator.dart`: product orchestration with injectable ports for service, preferences, deals, budgets, and time.
- Modify `frontend/lib/core/notifications.dart`: plugin adapter, channels, payload scheduling/cancellation, permission/settings helpers, pending count, cold-start/tap payload delivery.
- Modify `frontend/lib/main.dart`: initialize coordinator and route semantic notification payloads after navigator mount.
- Modify `frontend/lib/modules/auth/splash_page.dart`: replace scattered schedule calls with authenticated coordinator reconciliation.
- Modify `frontend/lib/modules/home/home_page.dart`: reconcile after refresh and consume auto-open behavior through coordinator callback.
- Modify `frontend/lib/modules/record/add_record_sheet.dart`: notify coordinator after successful save; remove duplicate local budget alert path.
- Modify `frontend/lib/modules/sync/sync_page.dart`: notify coordinator after successful import batch.
- Modify `frontend/lib/modules/settings/settings_page.dart`: use typed preferences and expose five independent switches, times, permission status, settings shortcut, and pending count.
- Modify `frontend/android/app/src/main/AndroidManifest.xml`: retain plugin boot/scheduled receivers and required permissions; remove unused push placeholder and exact-alarm permissions.
- Create `frontend/test/core/notification_policy_test.dart`: pure policy tests.
- Create `frontend/test/core/notification_preferences_test.dart`: persistence/default/migration tests.
- Create `frontend/test/core/notification_payload_test.dart`: payload tests.
- Create `frontend/test/core/notification_coordinator_test.dart`: coordinator behavior with fakes.
- Create `frontend/test/modules/notification_settings_test.dart`: settings interaction tests where Flutter tooling permits.

## Task 1: Add failing pure policy tests

**Files:** Create `frontend/test/core/notification_policy_test.dart`.

- [ ] Write tests for daily rolling dates, Monday report calculation, first-of-month calculation, stable ID ranges, budget threshold crossing and month-scoped dedupe keys, past/invalid deal filtering.
- [ ] Run `flutter test test/core/notification_policy_test.dart`; expected result is a compile failure because policy types do not exist.

## Task 2: Implement policy and models

**Files:** Create `frontend/lib/core/notification_models.dart`, `frontend/lib/core/notification_policy.dart`.

- [ ] Implement typed immutable models and validated constructors.
- [ ] Implement deterministic policy methods with injected `DateTime now`, including the exact ID ranges from the design.
- [ ] Run the policy test file and confirm all tests pass.

## Task 3: Add failing preferences tests and repository

**Files:** Create `frontend/test/core/notification_preferences_test.dart`, `frontend/lib/core/notification_preferences.dart`.

- [ ] Write tests for defaults, round-trip persistence, invalid time repair, and migration of `reminder_enabled`/`reminder_time`.
- [ ] Use an in-memory SharedPreferences test instance; run the tests and observe the expected missing-type failure before implementation.
- [ ] Implement `NotificationPreferencesRepository` with one key namespace and atomic save semantics.
- [ ] Run the preference tests and confirm they pass.

## Task 4: Add payload tests and semantic routing model

**Files:** Create `frontend/test/core/notification_payload_test.dart`; modify `frontend/lib/core/notification_models.dart`.

- [ ] Test encode/decode for daily, budget, weekly, monthly, deal payloads and malformed JSON fallback.
- [ ] Implement versioned JSON payload encoding and safe fallback destination.
- [ ] Run the payload tests and confirm they pass.

## Task 5: Refactor the plugin adapter

**Files:** Modify `frontend/lib/core/notifications.dart`.

- [ ] Preserve the existing public test-notification methods while adding typed schedule/cancel methods for every notification type.
- [ ] Define Android channels for daily, budget, weekly, monthly, deal, and test notifications.
- [ ] Use inexact scheduling and remove exact-alarm requests from the normal path.
- [ ] Return permission status, pending count, and the Android notification-settings action without throwing.
- [ ] Pass semantic payload strings to every scheduled notification.
- [ ] Support cold-start details and alive-app responses through one callback.

## Task 6: Add coordinator tests before coordinator implementation

**Files:** Create `frontend/test/core/notification_coordinator_test.dart`.

- [ ] Add fakes for preferences, notification service port, deals loader, budget loader, and clock.
- [ ] Test startup reconciliation, independent switch behavior, daily cancellation after today's record, budget 80%/100% one-time alerts, deal stale cancellation, idempotency, and per-type failure isolation.
- [ ] Run the coordinator tests and confirm they fail because the coordinator is missing.

## Task 7: Implement coordinator

**Files:** Create `frontend/lib/core/notification_coordinator.dart`.

- [ ] Implement injected ports and `reconcileAll`, `reconcileDaily`, `reconcileReports`, `reconcileDeals`, `evaluateBudget`, and `onRecordSaved`.
- [ ] Persist threshold dedupe keys only after a notification is successfully shown/scheduled.
- [ ] Keep failures isolated by notification type and avoid logging financial values or deal descriptions.
- [ ] Run policy, preference, payload, and coordinator tests together; confirm all pass.

## Task 8: Integrate app startup and routing

**Files:** Modify `frontend/lib/main.dart`, `frontend/lib/modules/auth/splash_page.dart`.

- [ ] Initialize the service and coordinator once before `runApp`.
- [ ] Move authenticated startup reconciliation behind the existing token check; do not fetch user-specific deals before authentication.
- [ ] Decode semantic payloads after navigator mount and route daily/home, budget/wallet, weekly/weekly_report, monthly/monthly_report, and deal/profile.
- [ ] Preserve daily add-record behavior through a typed pending action instead of an unscoped boolean where possible.

## Task 9: Integrate record/import refresh hooks

**Files:** Modify `frontend/lib/modules/home/home_page.dart`, `frontend/lib/modules/record/add_record_sheet.dart`, `frontend/lib/modules/sync/sync_page.dart`.

- [ ] Call `NotificationCoordinator.onRecordSaved` only after the server confirms a record.
- [ ] Remove the duplicate local budget dialog and let the coordinator issue one generic lock-screen notification plus in-app details.
- [ ] Reconcile budgets and schedules after Home refresh.
- [ ] Reconcile once after an import batch completes instead of once per row.

## Task 10: Replace settings UI and add widget tests

**Files:** Modify `frontend/lib/modules/settings/settings_page.dart`; create `frontend/test/modules/notification_settings_test.dart`.

- [ ] Replace raw SharedPreferences keys with the repository/coordinator API.
- [ ] Add five independent switches, relevant time pickers, pending count, permission state, Android settings action, immediate test, and 15-second test.
- [ ] Ensure permission denial leaves a feature disabled and displays an actionable message.
- [ ] Run widget tests; if the current global theme/page coupling prevents isolation, keep meaningful controller-level tests and record the limitation.

## Task 11: Android manifest and plugin receiver configuration

**Files:** Modify `frontend/android/app/src/main/AndroidManifest.xml`.

- [ ] Keep `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, vibration, wake lock, and the plugin-required scheduled/boot receivers for plugin v18.
- [ ] Remove unused third-party push metadata, `READ_PHONE_STATE`, and exact-alarm permissions unless the plugin build proves they are required.
- [ ] Keep the manifest cleartext flag only until the separate HTTPS migration is complete; document this dependency in the release notes.

## Task 12: Verification and release build

**Files:** No new source files; update `frontend/README.md` and root `README.md` only if the commands/feature description are stale.

- [ ] Run `flutter test` for all notification tests.
- [ ] Run `flutter analyze --no-pub` with a bounded timeout and capture exit code/output.
- [ ] Run `flutter build apk --release`; capture the generated APK path and size.
- [ ] Inspect the release APK manifest for notification permission/receiver entries.
- [ ] Manually verify Android 13 permission denial/grant, immediate test, 15-second test, force-close/restart restoration, each tap route, today's reminder suppression, monthly budget dedupe, and stale deal cancellation.
- [ ] Commit the implementation as `feat: add complete local notification center` after verification.

## Self-review checklist

- [ ] Every approved design requirement maps to a task above.
- [ ] No task uses placeholder language or undefined interfaces.
- [ ] All production code has a preceding failing test, except plugin/manifest wiring where the platform cannot be meaningfully unit-tested.
- [ ] Android is the release acceptance target; iOS-facing Dart interfaces remain platform-neutral.
