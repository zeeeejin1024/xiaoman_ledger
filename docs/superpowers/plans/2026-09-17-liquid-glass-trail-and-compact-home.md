# Liquid Glass Trail And Compact Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the rejected meteor navigation visual with a continuous glass pill and short soft smear, compact the home brand/subtitle layout, and bump the Android app version.

**Architecture:** Keep `NavigationMotionController` as the single motion source. A focused Flutter painter renders only rounded glass shapes, while `HomeHeader` uses one fixed-height stack so its accessible edit target does not increase layout height. The Remotion prototype mirrors the same visual contract without meteor-only state.

**Tech Stack:** Flutter/Dart CustomPainter and widget tests; React 19, Remotion, liquid-glass-react, Vitest; YAML application versioning.

---

### Task 1: Define the rejected visual contract in tests

**Files:**
- Modify: `frontend/test/modules/home/home_header_test.dart`
- Create: `frontend/test/widgets/liquid_glass_navigation_bar_test.dart`
- Modify: `remotion-nav-lab/src/remotionMarkup.test.ts`

- [ ] Add assertions for a maximum 56dp home header, title/subtitle alignment, a 44dp edit hit target, no meteor component reference, and a registered `LiquidGlassTrailPreview` composition.
- [ ] Run the focused Flutter and Vitest tests and confirm they fail because the old 86dp header and meteor markup are still present.

### Task 2: Replace the Flutter meteor painter

**Files:**
- Create: `frontend/lib/widgets/liquid_glass_trail_painter.dart`
- Create: `frontend/lib/widgets/liquid_glass_navigation_bar.dart`
- Delete: `frontend/lib/widgets/meteor_trail_painter.dart`
- Delete: `frontend/lib/widgets/meteor_navigation_bar.dart`
- Modify: `frontend/lib/modules/home/home_page.dart`

- [ ] Implement a static rounded glass base and one overlapping velocity-driven rounded smear; do not call `drawCircle` or `drawLine`.
- [ ] Keep drag, reverse, release targeting and haptic selection behavior connected to the existing controller.
- [ ] Replace the home-page import and widget name, then run the focused navigation tests until green.

### Task 3: Compact the Flutter home header

**Files:**
- Modify: `frontend/lib/modules/home/home_header.dart`
- Modify: `frontend/lib/modules/home/home_page.dart`

- [ ] Build the brand block within a fixed 52dp stack: 34dp mark, title on the first line, subtitle and edit label on the second line, settings at 48dp.
- [ ] Keep the edit label visually small while its transparent hit region is at least 44×44dp.
- [ ] Change the post-header spacing from `AppSpacing.xl` to `AppSpacing.md` and run the focused widget tests until green.

### Task 4: Simplify the Remotion prototype

**Files:**
- Create: `remotion-nav-lab/src/components/LiquidGlassSmear.tsx`
- Modify: `remotion-nav-lab/src/components/LiquidGlassTarget.tsx`
- Modify: `remotion-nav-lab/src/components/NavigationScene.tsx`
- Modify: `remotion-nav-lab/src/ComparisonComposition.tsx`
- Modify: `remotion-nav-lab/src/Composition.tsx`
- Modify: `remotion-nav-lab/src/index.css`
- Delete: `remotion-nav-lab/src/components/MeteorTrail.tsx`

- [ ] Drive the glass target from continuous page position and derive one wide smear from velocity.
- [ ] Remove meteor head, line, mote, afterimage and ripple rendering and rename the preview composition.
- [ ] Run Vitest, ESLint/TypeScript and the Remotion bundle.

### Task 5: Bump version and verify

**Files:**
- Modify: `frontend/pubspec.yaml`
- Modify: `frontend/lib/core/constants.dart`
- Modify: `frontend/test/core/version_test.dart`

- [ ] Update all version sources to `7.0.3+30` and run the version test.
- [ ] Run `flutter test`, `flutter analyze`, `npm test`, `npm run lint`, and `npm run build`; report any unrelated pre-existing failures separately.
