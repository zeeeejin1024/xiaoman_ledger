import {describe, expect, it} from "vitest";
import {buildMeteorVisual} from "./meteorHistory";

describe("buildMeteorVisual", () => {
  it("makes a fast trail longer than a slow trail", () => {
    const slow = buildMeteorVisual(
      {
        page: 1,
        velocity: 0.004,
        targetPage: 1,
        phase: "slow-drag",
        isDragging: true,
      },
      88,
    );
    const fast = buildMeteorVisual(
      {
        page: 1,
        velocity: 0.032,
        targetPage: 2,
        phase: "fling",
        isDragging: false,
      },
      88,
    );
    expect(fast.tailLength).toBeGreaterThan(slow.tailLength * 1.6);
  });

  it("places history behind the direction of travel", () => {
    const right = buildMeteorVisual(
      {
        page: 2,
        velocity: 0.03,
        targetPage: 3,
        phase: "fling",
        isDragging: false,
      },
      88,
    );
    const left = buildMeteorVisual(
      {
        page: 2,
        velocity: -0.03,
        targetPage: 1,
        phase: "reverse",
        isDragging: true,
      },
      88,
    );
    expect(right.history.every((point) => point.x <= right.headX)).toBe(true);
    expect(left.history.every((point) => point.x >= left.headX)).toBe(true);
  });

  it("limits decorative motes to three", () => {
    const fast = buildMeteorVisual(
      {
        page: 1.5,
        velocity: 0.04,
        targetPage: 2,
        phase: "fling",
        isDragging: false,
      },
      88,
    );
    expect(fast.motes.length).toBeLessThanOrEqual(3);
  });
});
