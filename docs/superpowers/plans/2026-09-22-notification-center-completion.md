# Notification Center Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the configurable Android local-notification center for daily reminders, reports, budgets, deals, permissions, diagnostics, and recovery.

**Architecture:** Keep `NotificationPreferences` as the persisted model and `NotificationCoordinator` as the scheduling boundary. The page edits immutable copies and delegates every change to the coordinator; platform notification code remains in `NotificationService`.

**Tech Stack:** Flutter/Dart, `flutter_local_notifications`, SharedPreferences, Flutter widget tests, Android API 36.

---

### Task 1: Lock preference and scheduling behavior with tests

**Files:**
- Create: `frontend/test/modules/notifications/notification_center_behavior_test.dart`
- Modify: `frontend/test/core/notifications/platform_scheduler_test.dart` only if a missing assertion is needed

- [ ] **Step 1: Write tests** for time formatting, weekday/day labels, and coordinator persistence when a rule is enabled or disabled.
- [ ] **Step 2: Run the focused tests** with `flutter test test/modules/notifications/notification_center_behavior_test.dart` and confirm the missing helpers/behavior fails.
- [ ] **Step 3: Implement only the smallest helpers** needed by the page and coordinator.
- [ ] **Step 4: Re-run the focused tests** and confirm they pass.

### Task 2: Implement complete notification-center controls

**Files:**
- Modify: `frontend/lib/modules/notifications/notification_center_page.dart`
- Modify: `frontend/lib/core/notification_coordinator.dart` only when UI exposes an existing rule not reconciled

- [ ] **Step 1: Add reusable rule-card builders** for switch, time picker, weekday selector, and month-day selector.
- [ ] **Step 2: Wire each save to `requestPermissionAndUpdate`**, reload state, and show an actionable failure message.
- [ ] **Step 3: Add separate cards for daily, weekly, monthly, budget, and deals; expose current values and next status.
- [ ] **Step 4: Keep hit targets at least 48dp and guard every async state update with `mounted`.
- [ ] **Step 5: Add widget assertions for visible labels and controls, then run the focused widget tests.

### Task 3: Improve diagnostics and device recovery guidance

**Files:**
- Modify: `frontend/lib/modules/notifications/notification_diagnostics_page.dart`
- Modify: `frontend/lib/modules/notifications/notification_help_page.dart` only for missing actionable status

- [ ] **Step 1: Show permission status and queue state with refresh timestamps.
- [ ] **Step 2: Report the result of immediate and scheduled tests instead of silently swallowing failure.
- [ ] **Step 3: Keep manufacturer-specific system/background settings buttons.
- [ ] **Step 4: Run notification tests and widget tests.

### Task 4: Full verification and release artifact

**Files:**
- Modify: `frontend/pubspec.yaml` and `frontend/lib/core/constants.dart` only if a version increment is required by the release policy.
- Create: `releases/android/<versioned-apk>` and matching SHA-256 file.

- [ ] **Step 1: Run `flutter test` and `python -m pytest -q`.
- [ ] **Step 2: Run `flutter build apk --release` using an ASCII `PUB_CACHE` if the Windows username path breaks JNI.
- [ ] **Step 3: Inspect embedded APK `versionName` and `versionCode`, then calculate SHA-256.
- [ ] **Step 4: Check ADB devices and install/launch only if a device is actually listed; otherwise report the limitation.
