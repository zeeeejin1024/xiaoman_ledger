import {describe, expect, it} from "vitest";
import {getGestureSample} from "./gestureTimeline";

describe("getGestureSample", () => {
  it("produces positive velocity during the fast fling", () => {
    const sample = getGestureSample(78, 30);
    expect(sample.phase).toBe("fling");
    expect(sample.velocity).toBeGreaterThan(0.018);
  });

  it("reverses direction without teleporting", () => {
    const before = getGestureSample(117, 30);
    const after = getGestureSample(123, 30);
    expect(Math.abs(after.page - before.page)).toBeLessThan(0.35);
    expect(after.velocity).toBeLessThan(0);
  });

  it("keeps the page within the five-page range", () => {
    for (let frame = 0; frame < 210; frame++) {
      expect(getGestureSample(frame, 30).page).toBeGreaterThanOrEqual(0);
      expect(getGestureSample(frame, 30).page).toBeLessThanOrEqual(4);
    }
  });
});
