# Android Notification Center Design

**Date:** 2026-09-08  
**Status:** Approved in conversation; awaiting written-spec confirmation  
**Scope:** Android implementation with platform-neutral interfaces reserved for iOS

## Goal

Build a complete, reliable local notification center for XiaoMan Ledger. It must cover daily bookkeeping reminders, budget threshold alerts, weekly and monthly reports, deal reminders, per-type settings, permission feedback, notification tap routing, deduplication, and schedule restoration after app or device restart.

## Product Behavior

### Daily bookkeeping reminder

- The user can enable or disable it and choose a time; default time is 21:00.
- When enabled, Android schedules a rolling 90-day set of one-shot notifications instead of one repeating alarm.
- When the user successfully records any transaction dated today, today's pending reminder is cancelled. Future days remain scheduled.
- Opening the app reconciles and extends the 90-day window.
- Tapping the notification opens Home and then the add-record sheet.

### Budget alerts

- The user can enable or disable budget alerts independently.
- After records are refreshed or an expense is saved/imported, the coordinator evaluates configured category/wallet budgets against current-month spending.
- Crossing 80% produces one warning for that budget and month.
- Crossing 100% produces one over-budget alert for that budget and month.
- Alerts do not repeat at the same threshold during the same calendar month. Deduplication state is stored locally and old months are pruned.
- Tapping an alert opens the Wallet page.

### Weekly report

- Independent switch, enabled by default only after notification permission is granted.
- Default schedule: Monday 09:00, configurable day and time in the settings model even if the first UI exposes only time.
- Tapping opens WeeklyReportPage.

### Monthly report

- Independent switch, enabled by default only after notification permission is granted.
- Default schedule: day 1 at 09:00.
- Tapping opens MonthlyReportPage.

### Deal reminders

- Independent switch.
- The app reads active deals from `/api/v1/deals` and schedules a one-shot reminder at 09:00 on each future `remind_date`.
- A deal with a date in the past is not scheduled. A deal completed/deleted on the server is removed at the next reconciliation.
- Notification IDs are derived from stable deal identities and collision-checked. The payload carries the semantic route, so routing never depends on numeric ID ranges.
- Tapping opens Profile, where the existing deal UI is available.

### Notification settings

- Show notification permission status and a button to open Android app notification settings when denied.
- Expose separate switches for daily reminders, budget alerts, weekly reports, monthly reports, and deal reminders.
- Expose relevant time pickers.
- Show the number of pending scheduled notifications.
- Keep immediate-test and 15-second scheduled-test actions.
- A switch is persisted only after the required system permission is available and scheduling succeeds. Failure must leave the switch off and show a useful message.

## Architecture

### `NotificationPreferences`

A typed immutable model owns all notification settings. `NotificationPreferencesRepository` is the only code that reads/writes their SharedPreferences keys. This replaces scattered string keys in SettingsPage and SplashPage.

Settings include:

- `dailyEnabled`, `dailyHour`, `dailyMinute`
- `budgetEnabled`
- `weeklyEnabled`, `weeklyWeekday`, `weeklyHour`, `weeklyMinute`
- `monthlyEnabled`, `monthlyDay`, `monthlyHour`, `monthlyMinute`
- `dealsEnabled`, `dealsHour`, `dealsMinute`

### `NotificationService`

This is the platform adapter around `flutter_local_notifications`. It owns initialization, Android permission checks, channel definitions, scheduling/cancelling, pending-request inspection, boot restoration support, and notification response payload delivery.

It does not fetch API data and does not decide product policy.

### `NotificationCoordinator`

This application service owns product rules. It loads preferences, asks the service to reconcile schedules, fetches active deals through a small injected loader, evaluates budget snapshots, records threshold deduplication, and handles `onRecordSaved`.

The coordinator is invoked:

- during authenticated app startup;
- after notification settings change;
- after a successful record creation/import;
- after deal changes;
- when Home refreshes, to reconcile budget state and rolling schedules.

Failures are isolated per notification type: a deal API failure must not remove daily/report reminders.

### Navigation payloads

Every notification uses a JSON payload with a version and semantic destination:

```json
{"v":1,"type":"daily","route":"home","action":"add_record"}
```

Supported types/routes are `daily/home`, `budget/wallet`, `weekly/weekly_report`, `monthly/monthly_report`, and `deal/profile`. Unknown or malformed payloads fall back to Home without throwing.

The notification plugin reports both cold-start launch details and taps received while the app is alive. Navigation is deferred until the navigator is mounted.

## Android Integration

- Keep `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, and the plugin-required scheduled notification receivers.
- Use inexact scheduling, so exact-alarm permissions are not required. Remove `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM` unless later product requirements prove exact-to-the-minute delivery is essential.
- Remove unused placeholder metadata and permissions for an unconfigured third-party push service.
- Register the flutter_local_notifications scheduled-notification and boot receivers required by plugin v18.
- Android is the only release acceptance target for this iteration.

The Dart interfaces remain platform-neutral. iOS initialization settings and permission implementation are represented by a supported branch, but iOS build, entitlements, exact presentation behavior, and device verification are explicitly deferred.

## Schedule Identity

Notification IDs use non-overlapping spaces:

- daily rolling reminders: 100000-100089
- weekly report: 200000
- monthly report: 200001
- test notifications: 200098-200099
- deal reminders: 300000-399999
- immediate budget alerts: 400000-499999

Correctness does not depend on these ranges because all navigation uses payloads.

## Data Flow

### Startup reconciliation

```text
Splash authenticates user
  -> coordinator.reconcileAll()
  -> load typed preferences
  -> inspect permission
  -> reconcile daily/report schedules
  -> fetch active deals and reconcile deal schedules
  -> inspect pending requests for settings UI
```

### Record save

```text
record API succeeds
  -> coordinator.onRecordSaved(recordDate, recordType)
  -> if recordDate is today: cancel today's daily reminder
  -> if expense: load current budget snapshot
  -> emit newly crossed 80%/100% alerts only
```

### Settings change

```text
user changes a switch/time
  -> check/request notification permission
  -> attempt new schedule
  -> persist typed settings only on success
  -> refresh pending count and visible state
```

## Error Handling

- Permission denied: keep requested feature disabled and offer Android settings.
- Exact delivery unavailable: use inexact scheduling; do not request exact alarm permission.
- Invalid saved time: fall back to documented defaults and rewrite valid settings.
- Scheduling failure: preserve unrelated notification types and report the affected type.
- Deal API unavailable: preserve already scheduled daily/report notifications; do not crash startup.
- Invalid deal date: skip the deal and log only its ID, never private description text.
- Malformed notification payload: navigate to Home.
- Notification operations are idempotent: reconciling twice produces the same pending set.

## Privacy

- Notification bodies avoid displaying exact balances, account names, phone numbers, or transaction notes on the lock screen.
- Budget notifications use generic text such as “有一项预算已达到 80%”。Details are visible only after opening the authenticated app.
- Logs contain event types and IDs, not financial values or deal descriptions.

## Testing Strategy

### Unit tests

- Preference defaults, round-trip persistence, and invalid-value repair.
- Next daily/weekly/monthly occurrence calculations at boundary times.
- Rolling daily ID/date mapping and cancellation for today's successful record.
- Budget 80% and 100% threshold crossing, monthly reset, and repeat suppression.
- Deal scheduling filters past/invalid dates and cancels removed deals.
- Payload encode/decode and malformed-payload fallback.
- Coordinator idempotency and per-type failure isolation using small fake ports.

### Widget tests

- Settings show all five switches and correct enabled controls.
- Denied permission leaves a switch off and exposes the settings action.
- Successful time change persists and refreshes the pending count.

### Android verification

- Build a release APK.
- Install on an Android 13+ device/emulator and verify permission flow.
- Verify immediate and 15-second tests.
- Verify daily reminder survives force close and device reboot.
- Verify each payload opens the correct destination.
- Verify recording today suppresses only today's daily reminder.
- Verify 80%/100% budget alerts occur once per month.

## Out of Scope

- FCM, JPush, Huawei Push Kit, Xiaomi/OPPO/vivo vendor push.
- Server-originated marketing notifications.
- Cross-device notification preference sync.
- iOS device/build acceptance in this iteration.
- Broader HTTPS, auth, database migration, category isolation, and import redesign work; those remain separate P0/P1 projects from the full-stack audit.

## Acceptance Criteria

1. All five notification types have independent persisted controls.
2. Android permission denial never leaves a false enabled state.
3. Pending schedules are restored/reconciled after app and device restart.
4. Daily reminders can suppress today without suppressing future days.
5. Budget thresholds alert at most once per budget, threshold, and month.
6. Deal changes reconcile without accumulating stale notifications.
7. Every notification tap routes by validated payload.
8. Automated tests cover scheduling policy and settings behavior.
9. Android release build succeeds; iOS-facing interfaces remain compilable by design but are not release-tested.
