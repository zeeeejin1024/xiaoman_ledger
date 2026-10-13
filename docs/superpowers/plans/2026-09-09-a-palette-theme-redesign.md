# A Palette Theme Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 A「石墨蓝 · 蔷薇莓」配色落到 Android Flutter 前端，修复主题切换不刷新导航栏的问题，更新 Android 品牌资源，并发布版本 `5.8.0+6`。

**Architecture:** `AppColors` 继续作为兼容旧调用点的主题 token 入口，同时增加可监听的 `ValueNotifier`。`XiaojiaApp` 监听该 notifier 后重建 `MaterialApp`，让 Material 主题、导航栏与页面 token 同步刷新；各设置页只负责选择并应用主题。Android 自适应图标与通知图标统一使用石墨蓝背景、蔷薇莓/雾青前景，iOS 资源保留不动。

**Tech Stack:** Flutter/Dart, Material 3, `ValueListenableBuilder`, flutter_test, Android VectorDrawable, pubspec versioning.

---

### Task 1: Lock the requested palette and version behavior with tests

**Files:**
- Create: `frontend/test/core/theme_test.dart`
- Modify: `frontend/test/core/version_test.dart`

- [x] **Step 1: Write failing tests** for the A palette tokens, observable theme changes, and `5.8.0+6` metadata.
- [x] **Step 2: Run the focused suite** with `flutter test test/core/theme_test.dart test/core/version_test.dart`; after repairing the worktree dependency index, it passed against the implemented behavior.

### Task 2: Make global theme changes observable

**Files:**
- Modify: `frontend/lib/core/theme.dart`
- Modify: `frontend/lib/main.dart`
- Modify: `frontend/lib/modules/profile/profile_page.dart`
- Modify: `frontend/lib/modules/settings/settings_page.dart`

- [x] **Step 1: Add `ValueNotifier<AppColorScheme>` and a single `AppColors.apply` path** that updates the notifier only when the scheme changes.
- [x] **Step 2: Wrap `MaterialApp` in `ValueListenableBuilder`** and apply status/navigation system-bar colors whenever the scheme changes.
- [x] **Step 3: Route profile/settings theme selection through the observable apply path** while preserving persisted scheme indexes.
- [x] **Step 4: Run the focused theme tests and confirm green.**

### Task 3: Apply A palette tokens to light and dark themes

**Files:**
- Modify: `frontend/lib/core/theme.dart`

- [x] **Step 1: Replace the persisted index-0 `warmAmber` token values** with background `#F4F4F0`, graphite blue `#273640`, mist teal `#587A86`, rose berry `#B45B6C`, and warm gold `#D9AD63` used only as an achievement accent.
- [x] **Step 2: Rebalance `darkInk` and `deepNight`** to charcoal blue-gray surfaces, mist teal structure color, and rose berry action color; remove gold as the dominant action color.
- [x] **Step 3: Update chart/button/navigation token usage** without removing legacy aliases used by existing pages.
- [x] **Step 4: Run all Flutter tests.**

### Task 4: Refresh Android icon resources without touching iOS

**Files:**
- Modify: `frontend/android/app/src/main/res/drawable/ic_launcher_brand_foreground.xml`
- Modify: `frontend/android/app/src/main/res/drawable/ic_notification.xml`
- Modify: `frontend/android/app/src/main/res/values/colors.xml`
- Modify: `frontend/mipmap-*` PNG resources and `frontend/assets/icon*.png` when regenerated deterministically
- Modify: `frontend/pubspec.yaml`

- [x] **Step 1: Update adaptive background and vector paths** to the A palette while keeping the unfinished-ring silhouette and Android notification monochrome constraints.
- [x] **Step 2: Regenerate raster launcher assets** at each density from the same source artwork; leave iOS asset catalogs untouched.
- [x] **Step 3: Update `flutter_launcher_icons` configuration** to the new adaptive background.
- [x] **Step 4: Run the icon resource test and inspect the generated Android resource names.**

### Task 5: Bump release metadata and verify the Android artifact

**Files:**
- Modify: `frontend/pubspec.yaml`
- Modify: `frontend/lib/core/constants.dart`

- [x] **Step 1: Set version to `5.8.0+6` and appVersion to `5.8.0`.**
- [x] **Step 2: Run `flutter pub get` and the full `flutter test`.**
- [x] **Step 3: Build `flutter build apk --release`.**
- [x] **Step 4: Verify APK version/resources with `aapt2`, signature with `apksigner`, and compute SHA-256.**
- [x] **Step 5: Review `git diff` and report the exact APK path, version, hash, tests, and any pre-existing warnings.**
