# Magnetic Meteor Remotion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static glow-bar Remotion prototype with a frame-driven magnetic meteor that derives its head, temporal trail, afterimages, motes, target absorption, and page movement from one deterministic motion sample.

**Architecture:** Pure TypeScript motion functions generate gesture samples, recent-position history, and magnetic target state. React components render those values without CSS animations, while a comparison composition places the old glow bar beside the new magnetic meteor for visual judgment. Pure behavior is covered by Vitest; Remotion lint, bundle, and still renders verify integration.

**Tech Stack:** TypeScript, React 19, Remotion 4.0.525, SVG, Vitest, CSS without transitions/keyframes.

---

## File structure

- Create `remotion-nav-lab/src/motion/types.ts`: shared motion data contracts.
- Create `remotion-nav-lab/src/motion/gestureTimeline.ts`: deterministic slow-drag, fast-fling, reversal, and settle samples.
- Create `remotion-nav-lab/src/motion/meteorHistory.ts`: temporal trail sampling and velocity-derived visual parameters.
- Create `remotion-nav-lab/src/motion/magneticTarget.ts`: attraction curve, icon compression, ripple, and absorption state.
- Create `remotion-nav-lab/src/motion/*.test.ts`: unit tests for direction, velocity, decay, bounds, and target behavior.
- Create `remotion-nav-lab/src/components/MeteorTrail.tsx`: SVG trail, core, afterimages, and motes.
- Create `remotion-nav-lab/src/components/NavigationScene.tsx`: phone UI, page strip, icons, and shared motion rendering.
- Create `remotion-nav-lab/src/components/LegacyGlowBar.tsx`: small explicit representation of the rejected prototype.
- Create `remotion-nav-lab/src/ComparisonComposition.tsx`: labeled old/new comparison and timeline phase indicators.
- Modify `remotion-nav-lab/src/Composition.tsx`: register the new composition.
- Modify `remotion-nav-lab/src/index.css`: layout only; remove every CSS animation/keyframe.
- Modify `remotion-nav-lab/package.json`: add Vitest and test scripts.

### Task 1: Add deterministic gesture timeline

**Files:**
- Create: `remotion-nav-lab/src/motion/types.ts`
- Create: `remotion-nav-lab/src/motion/gestureTimeline.ts`
- Create: `remotion-nav-lab/src/motion/gestureTimeline.test.ts`
- Modify: `remotion-nav-lab/package.json`

- [ ] **Step 1: Add the test runner**

Run:

```powershell
npm install --save-dev vitest
```

Add scripts:

```json
"test": "vitest run",
"test:watch": "vitest"
```

- [ ] **Step 2: Write failing timeline tests**

```ts
import {describe, expect, it} from 'vitest';
import {getGestureSample} from './gestureTimeline';

describe('getGestureSample', () => {
  it('produces positive velocity during the fast fling', () => {
    const sample = getGestureSample(78, 30);
    expect(sample.phase).toBe('fling');
    expect(sample.velocity).toBeGreaterThan(0.018);
  });

  it('reverses direction without teleporting', () => {
    const before = getGestureSample(117, 30);
    const after = getGestureSample(123, 30);
    expect(Math.abs(after.page - before.page)).toBeLessThan(0.35);
    expect(after.velocity).toBeLessThan(0);
  });

  it('keeps the page within the five-page range', () => {
    for (let frame = 0; frame < 210; frame++) {
      expect(getGestureSample(frame, 30).page).toBeGreaterThanOrEqual(0);
      expect(getGestureSample(frame, 30).page).toBeLessThanOrEqual(4);
    }
  });
});
```

- [ ] **Step 3: Run the test and verify RED**

Run: `npm test -- src/motion/gestureTimeline.test.ts`

Expected: FAIL because `getGestureSample` does not exist.

- [ ] **Step 4: Implement the timeline API**

```ts
export type GesturePhase = 'idle' | 'slow-drag' | 'fling' | 'reverse' | 'settle';

export type GestureSample = {
  page: number;
  velocity: number;
  targetPage: number;
  phase: GesturePhase;
  isDragging: boolean;
};
```

Implement `getGestureSample(frame, fps)` with five deterministic segments: idle `0–14`, slow drag `15–64`, fling `65–99`, reversal `100–139`, and settle `140–209`. Calculate velocity from the current and previous frame rather than storing independent state, clamp pages to `0–4`, and limit the fling to one page.

- [ ] **Step 5: Run tests and commit**

Run: `npm test -- src/motion/gestureTimeline.test.ts`

Expected: 3 tests pass.

Commit:

```powershell
git add remotion-nav-lab/package.json remotion-nav-lab/package-lock.json remotion-nav-lab/src/motion
git commit -m "test: define magnetic meteor gesture timeline"
```

### Task 2: Derive temporal trail samples from motion history

**Files:**
- Create: `remotion-nav-lab/src/motion/meteorHistory.ts`
- Create: `remotion-nav-lab/src/motion/meteorHistory.test.ts`

- [ ] **Step 1: Write failing trail tests**

```ts
import {describe, expect, it} from 'vitest';
import {buildMeteorVisual} from './meteorHistory';

describe('buildMeteorVisual', () => {
  it('makes a fast trail longer than a slow trail', () => {
    const slow = buildMeteorVisual({page: 1, velocity: 0.004, targetPage: 1, phase: 'slow-drag', isDragging: true}, 88);
    const fast = buildMeteorVisual({page: 1, velocity: 0.032, targetPage: 2, phase: 'fling', isDragging: false}, 88);
    expect(fast.tailLength).toBeGreaterThan(slow.tailLength * 1.6);
  });

  it('places history behind the direction of travel', () => {
    const right = buildMeteorVisual({page: 2, velocity: 0.03, targetPage: 3, phase: 'fling', isDragging: false}, 88);
    const left = buildMeteorVisual({page: 2, velocity: -0.03, targetPage: 1, phase: 'reverse', isDragging: true}, 88);
    expect(right.history.every((point) => point.x <= right.headX)).toBe(true);
    expect(left.history.every((point) => point.x >= left.headX)).toBe(true);
  });

  it('limits decorative motes to three', () => {
    const fast = buildMeteorVisual({page: 1.5, velocity: 0.04, targetPage: 2, phase: 'fling', isDragging: false}, 88);
    expect(fast.motes.length).toBeLessThanOrEqual(3);
  });
});
```

- [ ] **Step 2: Verify RED**

Run: `npm test -- src/motion/meteorHistory.test.ts`

Expected: FAIL because `buildMeteorVisual` does not exist.

- [ ] **Step 3: Implement velocity-driven visual data**

Define:

```ts
export type TrailPoint = {x: number; y: number; opacity: number; radius: number};
export type MeteorVisual = {
  headX: number;
  headY: number;
  stretch: number;
  tailLength: number;
  history: TrailPoint[];
  afterimages: TrailPoint[];
  motes: TrailPoint[];
};
```

Map absolute velocity to an `18–101px` tail range for an `88px` tab width. Generate `8–14` history points with exponential opacity decay. Put history opposite the velocity direction. Emit zero motes below the fling threshold and at most three deterministic motes above it.

- [ ] **Step 4: Verify GREEN and commit**

Run: `npm test -- src/motion/meteorHistory.test.ts`

Expected: 3 tests pass.

Commit:

```powershell
git add remotion-nav-lab/src/motion/meteorHistory.ts remotion-nav-lab/src/motion/meteorHistory.test.ts
git commit -m "feat: derive meteor trail from velocity history"
```

### Task 3: Add magnetic target absorption

**Files:**
- Create: `remotion-nav-lab/src/motion/magneticTarget.ts`
- Create: `remotion-nav-lab/src/motion/magneticTarget.test.ts`

- [ ] **Step 1: Write failing magnetic target tests**

```ts
import {describe, expect, it} from 'vitest';
import {getMagneticTargetState} from './magneticTarget';

describe('getMagneticTargetState', () => {
  it('does not bend before the final eighteen percent', () => {
    expect(getMagneticTargetState(0.7).bend).toBe(0);
  });

  it('bends and shrinks the core near impact', () => {
    const state = getMagneticTargetState(0.94);
    expect(state.bend).toBeGreaterThan(0);
    expect(state.coreScale).toBeLessThan(1);
  });

  it('creates a short ripple only after impact', () => {
    expect(getMagneticTargetState(1).rippleOpacity).toBeGreaterThan(0);
    expect(getMagneticTargetState(1.4).rippleOpacity).toBe(0);
  });
});
```

- [ ] **Step 2: Verify RED**

Run: `npm test -- src/motion/magneticTarget.test.ts`

Expected: FAIL because `getMagneticTargetState` does not exist.

- [ ] **Step 3: Implement magnetic state**

```ts
export type MagneticTargetState = {
  bend: number;
  coreScale: number;
  iconScaleX: number;
  iconScaleY: number;
  rippleOpacity: number;
  rippleScale: number;
};
```

Return zero bend before progress `0.82`. Between `0.82–1`, use a cubic ease to bend the tail toward the target and shrink the core. At impact compress the icon horizontally to `0.96`, then recover with low overshoot. Fade the ripple completely by normalized progress `1.4`.

- [ ] **Step 4: Verify GREEN and commit**

Run: `npm test -- src/motion/magneticTarget.test.ts`

Expected: 3 tests pass.

Commit:

```powershell
git add remotion-nav-lab/src/motion/magneticTarget.ts remotion-nav-lab/src/motion/magneticTarget.test.ts
git commit -m "feat: add magnetic meteor target absorption"
```

### Task 4: Build the frame-driven Remotion scene

**Files:**
- Create: `remotion-nav-lab/src/components/MeteorTrail.tsx`
- Create: `remotion-nav-lab/src/components/NavigationScene.tsx`
- Create: `remotion-nav-lab/src/components/LegacyGlowBar.tsx`
- Create: `remotion-nav-lab/src/ComparisonComposition.tsx`
- Modify: `remotion-nav-lab/src/Composition.tsx`
- Modify: `remotion-nav-lab/src/index.css`

- [ ] **Step 1: Add a source-guard test before production markup**

Create `remotion-nav-lab/src/remotionMarkup.test.ts`:

```ts
import {readFileSync} from 'node:fs';
import {describe, expect, it} from 'vitest';

describe('Remotion markup', () => {
  it('contains no CSS keyframes or animation declarations', () => {
    const css = readFileSync(new URL('./index.css', import.meta.url), 'utf8');
    expect(css).not.toMatch(/@keyframes|animation\s*:/);
  });

  it('registers the magnetic comparison composition', () => {
    const source = readFileSync(new URL('./Composition.tsx', import.meta.url), 'utf8');
    expect(source).toContain('MagneticMeteorComparison');
  });
});
```

- [ ] **Step 2: Verify RED**

Run: `npm test -- src/remotionMarkup.test.ts`

Expected: FAIL because the CSS still contains `@keyframes` and the new composition is not registered.

- [ ] **Step 3: Implement the scene**

`MeteorTrail.tsx` renders one SVG containing:

- A wide, low-opacity history path.
- A narrow bright history path.
- Two or three velocity-gated afterimages.
- A stretched elliptical core.
- Zero to three deterministic motes.
- A target ripple.

`NavigationScene.tsx` uses `useCurrentFrame()` to call `getGestureSample()`, `buildMeteorVisual()`, and `getMagneticTargetState()`. It moves the page strip and meteor from the same `sample.page`, renders five cached-looking page cards, and applies target icon compression from the magnetic state.

`LegacyGlowBar.tsx` deliberately shows the old rectangular gradient behavior without reusing the new trail functions.

`ComparisonComposition.tsx` places the old and new scenes side by side, labels the active timeline phase, and includes visible markers for slow drag, fling, reversal, and absorption.

Remove `@keyframes drift` and every `animation:` declaration from `index.css`. CSS may only define static layout, colors, borders, and shadows.

- [ ] **Step 4: Verify tests, types, and bundle**

Run:

```powershell
npm test
npm run lint
npm run build
```

Expected: all unit tests pass, TypeScript and ESLint pass, and Remotion bundle completes.

- [ ] **Step 5: Commit**

```powershell
git add remotion-nav-lab/src remotion-nav-lab/package.json remotion-nav-lab/package-lock.json
git commit -m "feat: build magnetic meteor Remotion comparison"
```

### Task 5: Render validation frames and open Studio

**Files:**
- Create: `remotion-nav-lab/out/magnetic-meteor-slow.png`
- Create: `remotion-nav-lab/out/magnetic-meteor-fling.png`
- Create: `remotion-nav-lab/out/magnetic-meteor-reverse.png`
- Create: `remotion-nav-lab/out/magnetic-meteor-impact.png`

- [ ] **Step 1: Render four representative frames**

Run:

```powershell
npx remotion still MagneticMeteorComparison out/magnetic-meteor-slow.png --frame=42
npx remotion still MagneticMeteorComparison out/magnetic-meteor-fling.png --frame=82
npx remotion still MagneticMeteorComparison out/magnetic-meteor-reverse.png --frame=122
npx remotion still MagneticMeteorComparison out/magnetic-meteor-impact.png --frame=154
```

Expected: four PNG files render successfully.

- [ ] **Step 2: Inspect all frames**

Verify visually:

- Slow drag has a short restrained tail and no decorative motes.
- Fling has a visibly longer tapered tail and at most three motes.
- Reverse frame places the new trail behind the reversed direction without teleporting the core.
- Impact frame shows core absorption, icon compression, and one faint ripple.
- New effect is visibly different from the old rectangular glow bar.

- [ ] **Step 3: Start Remotion Studio**

Run: `npx remotion studio --no-open --port 62495`

Expected: Studio reports `Built` and `http://localhost:62495/MagneticMeteorComparison` returns HTTP 200.

- [ ] **Step 4: Final verification**

Run:

```powershell
npm test
npm run lint
```

Expected: clean pass with no TypeScript, ESLint, or test failures.

The rendered PNG files are review artifacts and do not need to be committed unless the user asks to preserve them in the repository.
