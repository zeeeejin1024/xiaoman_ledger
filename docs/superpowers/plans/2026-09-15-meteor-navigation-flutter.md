# 流星导航 Flutter 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将“轨道余辉”v2 预览实现为可点击、可横滑、带同步触感且稳定流畅的 Flutter 底部导航。

**Architecture:** 单个 `NavigationMotionController` 持有连续页索引；页面位移、底托和 `MeteorTrailPainter` 读取同一进度。点击用可中断控制器，拖动直接跟手，不重建缓存页面。

**Tech Stack:** Flutter AnimationController、CustomPainter、GestureDetector、HapticFeedback、RepaintBoundary、flutter_test。

---

## File Structure

- Create: `frontend/lib/widgets/meteor_navigation_bar.dart`
- Create: `frontend/lib/widgets/meteor_trail_painter.dart`
- Create: `frontend/lib/core/navigation_motion_controller.dart`
- Create: `frontend/test/widgets/meteor_navigation_bar_test.dart`
- Create: `frontend/test/core/navigation_motion_controller_test.dart`
- Modify: `frontend/lib/modules/home/home_page.dart`
- Modify: `frontend/lib/widgets/lazy_tab_host.dart`

### Task 1: Build one interruptible motion source

- [ ] **Step 1: Write RED controller tests**

```dart
testWidgets('rapid taps retarget from the current visual position', (tester) async {
  final controller = NavigationMotionController(vsync: tester);
  controller.animateTo(4);
  await tester.pump(const Duration(milliseconds: 80));
  final midpoint = controller.position;
  controller.animateTo(1);
  expect(controller.position, closeTo(midpoint, 0.01));
});

test('drag threshold accepts distance or velocity', () {
  expect(resolveTarget(origin: 1, progress: 1.19, velocity: 0), 2);
  expect(resolveTarget(origin: 1, progress: 1.05, velocity: 700), 2);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/core/navigation_motion_controller_test.dart`

Expected: FAIL because controller is absent.

- [ ] **Step 3: Implement controller**

```dart
Future<void> animateTo(int target) async {
  _animation?.stop();
  _animation = Tween<double>(begin: position, end: target.toDouble()).animate(
    CurvedAnimation(parent: driver, curve: const Cubic(0.25, 1, 0.5, 1)),
  )..addListener(() => position = _animation!.value);
  driver.duration = reduceMotion ? const Duration(milliseconds: 120) : const Duration(milliseconds: 220);
  await driver.forward(from: 0);
}
```

Drag updates assign continuous position directly. Apply 0.28 damping beyond indices 0 and 4.

- [ ] **Step 4: Verify GREEN and commit**

Run: `flutter test test/core/navigation_motion_controller_test.dart`

```powershell
git add frontend/lib/core/navigation_motion_controller.dart frontend/test/core/navigation_motion_controller_test.dart
git commit -m "feat: add interruptible navigation motion"
```

### Task 2: Draw bidirectional trail without layout animation

- [ ] **Step 1: Write painter/widget RED tests**

Assert rightward motion paints the tail before the core, leftward motion paints it after the core, reduce-motion paints neither tail nor landing ring, and the widget size stays constant.

- [ ] **Step 2: Run RED**

Run: `flutter test test/widgets/meteor_navigation_bar_test.dart`

Expected: FAIL because bar and painter are absent.

- [ ] **Step 3: Implement painter**

```dart
class MeteorTrailPainter extends CustomPainter {
  final double progress;
  final double velocity;
  final bool reduceMotion;
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 5;
    final core = Offset((progress + .5) * cell, 16);
    if (!reduceMotion && velocity.abs() > .01) paintDirectionalTail(canvas, core, velocity);
    paintCore(canvas, core);
  }
}
```

Tail length clamps to 32-64 logical pixels. Use one gradient line and one core; landing ring lives for 120ms only.

- [ ] **Step 4: Verify repaint isolation**

Wrap painter in `RepaintBoundary`; `shouldRepaint` compares only progress, velocity, theme colors and reduce-motion. No `BackdropFilter`, particle list or animated width/left/top.

- [ ] **Step 5: Commit**

```powershell
git add frontend/lib/widgets/meteor_navigation_bar.dart frontend/lib/widgets/meteor_trail_painter.dart frontend/test/widgets/meteor_navigation_bar_test.dart
git commit -m "feat: draw bidirectional meteor navigation"
```

### Task 3: Integrate tap, swipe, page continuity and haptics

- [ ] **Step 1: Add integration RED tests**

```dart
testWidgets('swipe moves page and nav from the same progress', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: HomePage()));
  await tester.drag(find.byKey(const ValueKey('tab-gesture-surface')), const Offset(-120, 0));
  await tester.pump();
  expect(readPageProgress(tester), closeTo(readNavProgress(tester), 0.01));
});
```

Also test one haptic per crossed center, reverse drag, fast repeated taps and state preservation.

- [ ] **Step 2: Replace Material `NavigationBar`**

Keep the existing five destinations and `LazyTabHost`; replace only the presentation/control surface. Do not rebuild loaded tab children during animation.

- [ ] **Step 3: Add motion accessibility**

Read `MediaQuery.disableAnimations`; disable tail/ring and use 120ms position feedback. Haptics use `selectionClick` and obey platform settings.

- [ ] **Step 4: Verify and release `6.6.0+25`**

Run: `flutter test test/core/navigation_motion_controller_test.dart test/widgets/meteor_navigation_bar_test.dart test/widgets/lazy_tab_host_test.dart`

Build/sign/hash and cover-install. Profile on Android 16 at 60Hz/high refresh with rapid taps, slow drag, fling, reverse and edge damping; record no visible jank or layout shifts.
