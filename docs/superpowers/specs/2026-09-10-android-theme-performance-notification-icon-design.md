# Android Theme, Performance, Notification, and Icon Design

**Date:** 2026-09-10  
**Target:** Android first; preserve existing iOS resources and behavior  
**Next release:** `5.8.1+7`

## Goal

Resolve four user-visible Android problems in one controlled release:

1. Theme changes must update the app navigation bar and Android system navigation bar visibly and consistently.
2. Switching primary tabs must remain smooth while preserving page state and avoiding repeated data loads.
3. A scheduled reminder must report success only after a future notification is actually present in the platform queue.
4. The launcher icon must use the same unfinished-ring geometry as the in-app brand mark and remain legible under Android launcher masks.

## Scope

This release changes the Flutter frontend, Android notification configuration, Android launcher assets, automated tests, and Android release artifact. It does not change backend APIs, database schemas, server deployment, or iOS icon assets.

Existing unrelated backend edits and user files must not be staged, reverted, moved, or deleted.

## Confirmed Causes

### Theme navigation mismatch

The global app theme already rebuilds through `AppColors.notifier`, but `HomePage` supplies its own `NavigationBar.backgroundColor` and `indicatorColor`. Those local values override `NavigationBarThemeData`. Four light themes also use navigation backgrounds that are white or visually indistinguishable, so a successful rebuild can still appear unchanged.

### Slow primary-tab switching

`HomePage.build` creates all six primary page widgets and passes only the selected widget to `AnimatedSwitcher`. A tab that leaves the tree loses its state and may run initialization, network loading, chart construction, and list work again when revisited. The fade transition also overlaps outgoing and incoming heavy pages.

### Scheduled reminder reports false success

Immediate notification testing uses `show`, while reminders use `zonedSchedule`; success in the first path does not validate the second. `NotificationCoordinator.reconcileAll` catches scheduling failures without returning them, and the settings page ignores the returned result before showing a success message. Pending queue state and next trigger time are not shown to the user.

### Launcher and in-app icons drift

The in-app mark is drawn by `UnfinishedRingMark`, while Android vector and raster launcher assets are maintained separately. Their path geometry, marker treatment, and safe area differ. Android launchers then apply device-specific masks, which makes those differences more visible at small sizes.

## Design

### 1. Theme ownership

`AppColorScheme` remains the single theme source. Add explicit navigation tokens for surface, indicator, selected content, unselected content, and system navigation surface. Every scheme must provide visibly distinct values while preserving contrast.

`NavigationBarThemeData` owns all navigation colors. `HomePage` may own layout and the top divider but must not override theme colors. The Android status and system navigation bars are reapplied from the same selected scheme whenever the notifier changes.

Theme selection persists only after a valid index is chosen. The visible page, application navigation, and system navigation update during the same frame without restarting the app.

### 2. Primary-tab lifecycle and motion

Primary pages are created lazily on first visit and retained for the lifetime of `HomePage`. Their scroll positions, selected filters, and loaded data remain intact across tab switches.

The body uses a retained stack with one active child. Inactive tabs are excluded from semantics and hit testing. `TickerMode` disables their animations, preventing charts and decorative motion from consuming frame time while hidden.

Tab motion is limited to a short, GPU-friendly opacity and vertical translation on the newly activated layer. It must not animate layout size, blur, or rebuild the outgoing page. Target duration is 160-200 ms with an ease-out curve. Android secondary routes use one consistent transition style and timing.

Data pages keep their existing APIs. This work prevents avoidable reloads; it does not introduce a new global state-management framework.

### 3. Verifiable notification scheduling

Introduce a structured scheduling result shared by the service, coordinator, and settings page. It contains:

- status: scheduled, permission denied, invalid time, platform unavailable, or scheduling failed;
- next trigger timestamp;
- number of pending requests after reconciliation;
- whether timing is exact or may be delayed;
- a user-safe failure message and a diagnostic code.

The notification service never silently treats a past or invalid non-repeating timestamp as success. Daily policy always resolves the selected time to the next future occurrence. After scheduling, the service queries pending notification requests and confirms that the expected ID exists.

The coordinator continues to protect startup from notification plugin failures, but startup reconciliation and user-initiated scheduling are separate entry points. Startup may log and continue; a user action must receive an explicit result.

The settings page shows success only when the expected request is pending. It then displays the next reminder time and queue state. Permission denial, unsupported platform state, and scheduling errors use distinct messages. Permission-related failures include an action to open system app settings.

The 15-second test uses the same scheduling and verification path as daily reminders. Immediate testing remains a separate control and is labelled as testing notification display only.

The default Android mode remains `inexactAllowWhileIdle` for broad compatibility and lower permission friction. The interface states that delivery may be delayed by the system. Exact-alarm support is not enabled in this release; it requires a separate product decision, manifest permission review, and store-policy review.

### 4. One brand-mark geometry

Create one documented set of normalized geometry constants for the unfinished ring: center, radius, stroke width, start angle, gap, marker position, marker radius, and three tick positions. `UnfinishedRingMark` consumes these constants for the animated in-app version.

Android adaptive foreground and legacy raster launcher assets are generated from the static progress-zero frame of the same geometry. The launcher background remains graphite blue; the main ring remains moon white; the marker remains rose berry. The foreground fits inside the Android adaptive icon safe zone so circular, rounded-square, and teardrop masks preserve the full mark.

The launcher icon is brand-fixed and does not change with the user's theme. In-app brand placements such as splash, login, and about use the brand palette. Functional progress rings may continue to use theme colors. The Android notification small icon remains a compliant monochrome silhouette.

The unused legacy `AppIconGenerator` wallet artwork is not used as an asset source. It should be removed only if reference checks still confirm that it has no runtime consumers.

## User Experience States

### Theme

- Selecting a theme updates the current screen and both navigation surfaces immediately.
- Reopening the app restores the same theme.

### Tab switch

- The selected navigation item responds immediately.
- Returning to a tab restores its previous scroll and filter state.
- A loading page continues its existing request rather than starting a duplicate request.

### Reminder

- Success: `下一次提醒：明天 21:00 · 已加入系统计划`.
- Inexact mode: `系统可能延迟几分钟送达`.
- Permission denied: explain the missing notification permission and offer system settings.
- Scheduling failed: do not claim success; show a retry action and retain the selected time.
- Queue empty after scheduling: treat as failure and expose a diagnostic code for support.

## Error Handling and Diagnostics

Notification failures are logged with operation, diagnostic code, target timestamp, schedule mode, and platform version, but never include authentication tokens or personal ledger data. The settings page exposes only user-safe wording.

Repeated reconciliation is serialized. A queued reconciliation runs after the current one finishes, and its result cannot overwrite a newer settings selection.

Theme and tab operations contain no network dependency. If a retained tab encounters a data error, it uses that page's existing retry behavior without resetting other tabs.

## Testing

### Automated

- Theme tests assert navigation and system-bar token changes for every scheme.
- Widget tests switch themes while `HomePage` is mounted and inspect resolved navigation colors.
- Widget tests switch tabs repeatedly and verify that each tab state initializes once and its state survives.
- Notification policy tests cover future time, current minute, past time, day rollover, and the Asia/Shanghai timezone.
- Notification service tests use an adapter seam to verify expected IDs and structured failure results.
- Settings tests ensure success is impossible when permission is denied, scheduling throws, or the expected pending ID is absent.
- Brand geometry tests verify a single source of normalized constants and Android safe-zone bounds.
- Version tests require `pubspec.yaml` `5.8.1+7` and app display version `5.8.1`.

### Android device acceptance

Run on at least one Android 13+ physical device:

1. Change through all themes and verify app navigation and gesture/navigation bar colors.
2. Switch among all six tabs repeatedly, then confirm scroll and filter state are retained.
3. Schedule a reminder two minutes in the future and confirm the settings page shows the same next trigger.
4. Repeat after force-closing the app, enabling battery restrictions, and rebooting the device.
5. Deny notification permission and verify that no success message appears.
6. Test the launcher icon with circular and rounded-square masks; use teardrop mask when supported by the launcher.
7. Verify the notification small icon is legible and monochrome.

Performance acceptance uses Flutter profile mode. Primary tab switching should not trigger repeated page initialization, and frame timing must show no repeatable long-frame burst caused by rebuilding the destination page. Visual judgment alone is not sufficient.

## Release Rules

- Increment both marketing version and build number for every installable update.
- This release is `5.8.1+7`; later APKs must not reuse it.
- Build the Android release APK only after the full Flutter test suite passes.
- Verify APK version metadata, signing certificate type, installability, and SHA-256.
- Publish the copy under `releases/android/` with the version in its filename and a matching checksum file.
- Preserve the original Flutter build output and all iOS assets.

## Implementation Order

1. Notification result model, scheduling verification, settings states, and notification tests.
2. Retained lazy tab host, motion, and lifecycle/performance tests.
3. Navigation theme tokens, removal of local overrides, and theme tests.
4. Shared brand geometry, Android icon generation, mask review, and icon tests.
5. Version bump, full regression suite, Android device acceptance, release build, signature check, and checksum.

## Out of Scope

- Exact-alarm permission and store-policy work.
- Backend or server changes.
- New state-management framework.
- New navigation information architecture.
- iOS icon replacement or iOS notification behavior changes.
- Redesigning unrelated screens or notification types.
