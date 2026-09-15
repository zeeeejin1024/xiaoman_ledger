# 全页面主题同步与实机闭环实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让缓存页面、路由页、打开中的弹层、状态栏和手势导航区在一次主题切换中同步更新且不重新请求数据。

**Architecture:** `AppColors.notifier` 继续作为唯一信号；页面、路由和 Overlay 统一通过响应式边界读取同一 scheme。系统栏样式在根 `AnnotatedRegion` 同帧更新。

**Tech Stack:** Flutter ValueListenableBuilder、Navigator、Overlay、SystemUiOverlayStyle、flutter_test、ADB Android 16。

---

## File Structure

- Create: `frontend/lib/core/themed_overlays.dart`
- Create: `frontend/test/core/themed_overlays_test.dart`
- Create: `frontend/test/modules/theme/full_theme_sync_test.dart`
- Modify: `frontend/lib/main.dart`
- Modify: `frontend/lib/core/router.dart`
- Modify: `frontend/lib/core/theme.dart`
- Modify: every call site of `showDialog` and `showModalBottomSheet` under `frontend/lib/modules/`
- Modify: `frontend/test/core/system_ui_theme_test.dart`

### Task 1: Reproduce cached-page and overlay failures

- [ ] **Step 1: Write RED integration test**

```dart
testWidgets('theme changes cached tabs, pushed route and open dialog in one frame', (tester) async {
  final requests = FakeRequestCounter();
  await tester.pumpWidget(testApp(requests));
  await openStatsThenSettingsDialog(tester);
  AppColors.apply(AppColorScheme.deepNight);
  await tester.pump();
  expect(pageColor(tester), AppColorScheme.deepNight.bg);
  expect(dialogColor(tester), AppColorScheme.deepNight.card);
  expect(systemUi(tester).statusBarIconBrightness, Brightness.light);
  expect(requests.total, requests.beforeThemeSwitch);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/modules/theme/full_theme_sync_test.dart`

Expected: at least the already-open Overlay fails to rebuild.

### Task 2: Centralize route and overlay theme boundaries

- [ ] **Step 1: Implement themed overlay helpers**

```dart
Future<T?> showAppDialog<T>({required BuildContext context, required WidgetBuilder builder}) {
  return showDialog<T>(context: context, builder: (context) => AppThemedPage(builder: (context, _) => builder(context)));
}

Future<T?> showAppBottomSheet<T>({required BuildContext context, required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(context: context, builder: (context) => AppThemedPage(builder: (context, _) => builder(context)));
}
```

Preserve existing `isScrollControlled`, `isDismissible`, background and route settings as named parameters.

- [ ] **Step 2: Replace direct overlay calls**

Search with `rg -n "showDialog|showModalBottomSheet" frontend/lib/modules`. Every user-facing call must use the helper; tests fail if a direct call remains outside the helper file.

- [ ] **Step 3: Wrap generated routes**

`AppRouter.onGenerateRoute` returns pages inside `AppThemedPage`. Keep route identity and state; do not assign scheme-dependent keys.

- [ ] **Step 4: Update root system UI in the same notifier frame**

```dart
ValueListenableBuilder<AppColorScheme>(
  valueListenable: AppColors.notifier,
  builder: (_, scheme, app) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: AppSystemUiStyle.forScheme(scheme),
    child: app!,
  ),
  child: const XiaojiaApp(),
)
```

- [ ] **Step 5: Verify GREEN and commit**

Run: `flutter test test/core/themed_overlays_test.dart test/modules/theme/full_theme_sync_test.dart test/core/system_ui_theme_test.dart`

```powershell
git add frontend/lib/core frontend/lib/main.dart frontend/lib/modules frontend/test/core frontend/test/modules/theme
git commit -m "fix: synchronize theme across routes and overlays"
```

### Task 3: Android 16 evidence matrix

- [ ] **Step 1: Release `6.6.1+26`**

Update both version sources; run full analyze/test/build, inspect APK version/signature/hash and cover-install without clearing data.

- [ ] **Step 2: Automate six-scheme traversal**

For each scheme, capture homepage, stats, savings, records, profile, wallet, report, settings and an open dialog. Execute warm-to-deep and deep-to-warm transitions without navigating away first.

- [ ] **Step 3: Check system surfaces and state preservation**

Record status bar/navigation bar pixel samples, current tab index, scroll position and API request counters. Any stale page, navigation-required refresh, extra data request or status bar mismatch fails the release.
