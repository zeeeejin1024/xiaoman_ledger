# Android UI Performance, Theme, and Launcher Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Android `5.8.2+8` with an exact in-app/launcher brand match, immediate system-bar theme updates, smooth state-preserving primary-tab transitions, and lower avoidable GPU/runtime memory churn.

**Architecture:** Make theme and system-bar styling declarative at the `MaterialApp` root, replace `AnimatedSwitcher` with a lazy retained tab host, and make one normalized Dart geometry class the source for both `CustomPainter` and generated Android launcher assets. Remove expensive blur layers from the shared card primitive and dispose transient controllers at their ownership boundary.

**Tech Stack:** Flutter/Dart, Material 3, Android adaptive icons, PowerShell/System.Drawing asset generation, `flutter_test`, Gradle Android release build.

---

## File map

- Create `frontend/lib/widgets/lazy_tab_host.dart`: lazy tab construction, retained state, inactive ticker/semantics/pointer suppression, and incoming transition.
- Create `frontend/lib/widgets/brand_mark_geometry.dart`: normalized unfinished-ring geometry shared by runtime painter and Android asset generator.
- Modify `frontend/lib/modules/home/home_page.dart`: use the retained host and remove local navigation color overrides.
- Modify `frontend/lib/main.dart`: install one declarative system UI overlay region and remove build-time platform side effects.
- Modify `frontend/lib/core/theme.dart`: expose scheme-derived overlay style, set app/navigation theme tokens, and remove shared card blur buffers.
- Modify `frontend/lib/widgets/unfinished_ring_mark.dart`: consume the shared geometry constants.
- Modify `frontend/tool/regenerate_android_icon.ps1`: parse the shared Dart constants and regenerate Android-only adaptive and legacy resources.
- Modify `frontend/pubspec.yaml`: configure launcher generation as Android-only and bump to `5.8.2+8`.
- Modify `frontend/lib/core/constants.dart`: bump displayed version to `5.8.2`.
- Delete `frontend/android/app/src/main/res/drawable/ic_launcher_brand_foreground.xml`: remove the obsolete hand-maintained foreground override.
- Modify Android launcher XML/PNG resources under `frontend/android/app/src/main/res`: point API 26+ to generated foreground assets and regenerate density-specific fallbacks.
- Create `frontend/test/widgets/lazy_tab_host_test.dart`: initialization, retention, pointer, and ticker behavior.
- Create `frontend/test/widgets/premium_card_performance_test.dart`: prevent reintroduction of per-card blur layers.
- Create `frontend/test/core/system_ui_theme_test.dart`: system-bar and app-navigation colors derive from the selected scheme.
- Create `frontend/test/core/launcher_icon_test.dart`: validate the active Android resource chain and single geometry source.
- Modify `frontend/test/core/version_test.dart`: lock the release version.

### Task 1: Declarative theme and system bars

**Files:**
- Create: `frontend/test/core/system_ui_theme_test.dart`
- Modify: `frontend/lib/core/theme.dart`
- Modify: `frontend/lib/main.dart`
- Modify: `frontend/lib/modules/home/home_page.dart`

- [ ] **Step 1: Write the failing theme tests**

Add tests that apply `mistBlue` and `deepNight`, then assert that `AppColors.systemUiOverlayStyle.systemNavigationBarColor`, icon brightness, `appTheme().navigationBarTheme.backgroundColor`, and `appTheme().appBarTheme.systemOverlayStyle` all resolve from the active scheme. Add a widget test that pumps `XiaojiaApp`, changes `AppColors.notifier`, and finds a root `AnnotatedRegion<SystemUiOverlayStyle>` with the new value.

```dart
expect(AppColors.systemUiOverlayStyle.systemNavigationBarColor, AppColors.navBg);
expect(appTheme().appBarTheme.systemOverlayStyle, AppColors.systemUiOverlayStyle);
expect(
  tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
    find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
  ).value.systemNavigationBarColor,
  AppColorScheme.deepNight.navBg,
);
```

- [ ] **Step 2: Verify the tests fail for the old imperative implementation**

Run: `flutter test test/core/system_ui_theme_test.dart`

Expected: FAIL because `systemUiOverlayStyle` and the root declarative region do not exist.

- [ ] **Step 3: Implement one scheme-derived overlay style**

In `AppColors`, replace `applySystemUi()` with a pure getter:

```dart
static SystemUiOverlayStyle get systemUiOverlayStyle => SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
  statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
  systemNavigationBarColor: navBg,
  systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
  systemNavigationBarDividerColor: divider,
);
```

Set `AppBarTheme.systemOverlayStyle` from this getter. In `MaterialApp.builder`, wrap the routed child with `AnnotatedRegion<SystemUiOverlayStyle>` using the same getter. Remove all `SystemChrome.setSystemUIOverlayStyle` calls from startup, builds, and theme selection.

Remove `backgroundColor` and `indicatorColor` from `HomePage.NavigationBar`, and remove the navigation container fill so `NavigationBarThemeData` is the only app-navigation color owner.

- [ ] **Step 4: Verify theme behavior**

Run: `flutter test test/core/theme_test.dart test/core/system_ui_theme_test.dart`

Expected: PASS with no platform-channel exception.

### Task 2: Lazy retained primary-tab host

**Files:**
- Create: `frontend/test/widgets/lazy_tab_host_test.dart`
- Create: `frontend/lib/widgets/lazy_tab_host.dart`
- Modify: `frontend/lib/modules/home/home_page.dart`

- [ ] **Step 1: Write failing lifecycle tests**

Use six builder counters and stateful probe pages. Verify initial pump builds only index 0, first visits build a page exactly once, revisits preserve a counter/scroll state, hidden pages ignore taps and semantics, and hidden ticker probes stop receiving frames.

```dart
expect(buildCounts, [1, 0, 0, 0, 0, 0]);
await tester.tap(find.text('统计'));
await tester.pumpAndSettle();
expect(buildCounts, [1, 1, 0, 0, 0, 0]);
await tester.tap(find.text('首页'));
await tester.pumpAndSettle();
expect(buildCounts, [1, 1, 0, 0, 0, 0]);
```

- [ ] **Step 2: Verify the host tests fail because the component is absent**

Run: `flutter test test/widgets/lazy_tab_host_test.dart`

Expected: compile failure for missing `LazyTabHost`.

- [ ] **Step 3: Implement the retained host**

Store visited children in an index-keyed map. On index changes, instantiate only the destination. Render retained layers in a `Stack`; each layer uses `Offstage`, `TickerMode`, `IgnorePointer`, and `ExcludeSemantics`. Animate only the active child with `AnimatedOpacity` and `AnimatedSlide`, using 180 ms and `Curves.easeOutCubic`. Keep stable `ValueKey<int>` values and fixed `Positioned.fill` constraints.

```dart
Widget _layer(int index, Widget child) {
  final active = index == widget.index;
  return Positioned.fill(
    child: TickerMode(
      enabled: active,
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeSemantics(
          excluding: !active,
          child: Offstage(offstage: !active, child: child),
        ),
      ),
    ),
  );
}
```

The actual animation must be applied without recreating or duplicating heavy child trees; if `Offstage` prevents the implicit incoming animation, keep the current child visible in a lightweight overlay keyed by index while retained page state remains in the stack.

- [ ] **Step 4: Integrate six primary page builders**

Replace the local `pages` list and `AnimatedSwitcher` in `HomePage` with builders for `_DashTab`, `StatsPage`, `SavingsPage`, `WalletPage`, `RecordsListPage`, and `ProfilePage`. Keep navigation haptics and selected-index changes immediate.

- [ ] **Step 5: Verify lifecycle and existing tests**

Run: `flutter test test/widgets/lazy_tab_host_test.dart`

Expected: PASS; each builder count stays at one after revisit and state remains present.

### Task 3: Remove avoidable GPU buffers and transient controller retention

**Files:**
- Create: `frontend/test/widgets/premium_card_performance_test.dart`
- Modify: `frontend/lib/core/theme.dart`
- Modify: `frontend/lib/modules/profile/profile_page.dart`
- Modify: `frontend/lib/modules/home/home_page.dart`

- [ ] **Step 1: Write the failing shared-card performance test**

Pump a `PremiumCard` and assert it has no `BackdropFilter` descendant while preserving clipping, border, background, shadow, and tap behavior.

```dart
expect(find.descendant(
  of: find.byType(PremiumCard),
  matching: find.byType(BackdropFilter),
), findsNothing);
```

- [ ] **Step 2: Verify the test fails against the current blur implementation**

Run: `flutter test test/widgets/premium_card_performance_test.dart`

Expected: FAIL because one `BackdropFilter` is found.

- [ ] **Step 3: Remove the global card blur buffer**

Keep `ClipRRect` and the existing card decoration, but remove `BackdropFilter(ImageFilter.blur(sigmaX: 16, sigmaY: 16))`. Use scheme-aware opaque/translucent fills that do not allocate a full backdrop blur layer for each of the 29 shared cards.

- [ ] **Step 4: Dispose locally-owned editing controllers**

Convert status/title dialogs to await their route result and dispose each locally-created `TextEditingController` in `finally`. Do not dispose controllers still owned by a mounted state object.

```dart
final controller = TextEditingController(text: initialValue);
try {
  await showModalBottomSheet<void>(context: context, builder: ...);
} finally {
  controller.dispose();
}
```

- [ ] **Step 5: Verify the focused performance tests**

Run: `flutter test test/widgets/premium_card_performance_test.dart test/widgets/lazy_tab_host_test.dart`

Expected: PASS and no pending ticker warnings.

### Task 4: Single-source in-app and Android launcher geometry

**Files:**
- Create: `frontend/lib/widgets/brand_mark_geometry.dart`
- Create: `frontend/test/core/launcher_icon_test.dart`
- Modify: `frontend/lib/widgets/unfinished_ring_mark.dart`
- Modify: `frontend/tool/regenerate_android_icon.ps1`
- Modify: `frontend/pubspec.yaml`
- Delete: `frontend/android/app/src/main/res/drawable/ic_launcher_brand_foreground.xml`
- Regenerate: `frontend/assets/icon.png`, `frontend/assets/icon_foreground.png`, and Android launcher resources under `frontend/android/app/src/main/res`

- [ ] **Step 1: Write failing geometry/resource-chain tests**

Verify `UnfinishedRingMark` imports `brand_mark_geometry.dart`; the generator reads that same file; API 26 launcher XML does not mention `ic_launcher_brand_foreground`; the obsolete XML is absent; the adaptive foreground resource exists; and `pubspec.yaml` has `ios: false` so Android regeneration cannot overwrite retained iOS assets.

```dart
expect(File('android/app/src/main/res/drawable/ic_launcher_brand_foreground.xml').existsSync(), isFalse);
expect(adaptiveXml, isNot(contains('ic_launcher_brand_foreground')));
expect(generator, contains('brand_mark_geometry.dart'));
expect(pubspec, contains('ios: false'));
```

- [ ] **Step 2: Verify tests fail on the old hand-maintained chain**

Run: `flutter test test/core/launcher_icon_test.dart test/widgets/unfinished_ring_mark_test.dart`

Expected: FAIL because the legacy foreground XML is active and no shared geometry class exists.

- [ ] **Step 3: Define normalized geometry once**

Create public numeric constants for center, radius, stroke, start angle, gap, primary marker progress/radius, gap marker offset/radius, and tick positions. Replace all corresponding literals in `_UnfinishedRingPainter` with these constants. Keep animation limited to sweep and primary marker progress deltas.

- [ ] **Step 4: Rebuild the Android-only generator**

Parse numeric constants from `brand_mark_geometry.dart`, draw the progress-zero ring/markers/ticks into transparent `icon_foreground.png`, draw the same foreground on graphite for legacy `icon.png`, and generate all density resources. Preserve every `frontend/ios` file byte-for-byte.

Set launcher config to `ios: false`, `android: true`, graphite adaptive background, and the generated transparent foreground. Run the launcher package so API 26 resources reference the generated foreground. Delete the obsolete hand-maintained XML.

- [ ] **Step 5: Generate and inspect assets**

Run: `powershell -ExecutionPolicy Bypass -File tool/regenerate_android_icon.ps1`

Run: `dart run flutter_launcher_icons`

Expected: Android resources are regenerated, iOS is skipped, and launcher XML no longer references `ic_launcher_brand_foreground`.

Open `assets/icon.png` and `assets/icon_foreground.png` for visual inspection at full size and downscaled launcher sizes. Confirm the ring is complete under circular and rounded-square masks and matches the non-animated in-app frame.

- [ ] **Step 6: Verify geometry and resource tests**

Run: `flutter test test/core/launcher_icon_test.dart test/widgets/unfinished_ring_mark_test.dart`

Expected: PASS.

### Task 5: Version, regression, and release artifact

**Files:**
- Modify: `frontend/pubspec.yaml`
- Modify: `frontend/lib/core/constants.dart`
- Modify: `frontend/test/core/version_test.dart`
- Create: `releases/android/Xiaojia-v5.8.2+8.apk`
- Create: `releases/android/Xiaojia-v5.8.2+8.apk.sha256`

- [ ] **Step 1: Update the version test first**

Change assertions to `AppConstants.appVersion == '5.8.2'` and `version: 5.8.2+8`.

- [ ] **Step 2: Verify the version test fails against `5.8.1+7`**

Run: `flutter test test/core/version_test.dart`

Expected: FAIL showing old source and display versions.

- [ ] **Step 3: Bump both version sources**

Set `frontend/pubspec.yaml` to `version: 5.8.2+8` and `AppConstants.appVersion` to `5.8.2`.

- [ ] **Step 4: Format and analyze**

Run: `dart format lib test`

Run: `flutter analyze`

Expected: exit 0 with no new errors.

- [ ] **Step 5: Run the full regression suite**

Run: `flutter test`

Expected: all tests PASS with zero failures.

- [ ] **Step 6: Build the Android release APK**

Run: `flutter build apk --release`

Expected: exit 0 and `build/app/outputs/flutter-apk/app-release.apk` exists.

- [ ] **Step 7: Verify embedded metadata and checksum**

Use Android build tools to inspect the APK and confirm package `com.xiaojia.xiaojia_ledger`, `versionName=5.8.2`, and `versionCode=8`. Copy it to `releases/android/Xiaojia-v5.8.2+8.apk`, compute SHA-256, and write the matching `.sha256` file.

- [ ] **Step 8: Device acceptance**

Install after uninstalling the previous package to clear launcher cache. On the connected Android device, verify: icon appearance; all six tab transitions; retained tab scroll/state; immediate mist-blue to deep-night system-bar changes; 2-minute scheduled reminder; and stable memory/ticker behavior after repeated tab switching. Record any OEM launcher cache behavior separately from APK resource correctness.
