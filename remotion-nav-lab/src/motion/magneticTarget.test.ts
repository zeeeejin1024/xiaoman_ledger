import {describe, expect, it} from "vitest";
import {getMagneticTargetState} from "./magneticTarget";

describe("getMagneticTargetState", () => {
  it("does not bend before the final eighteen percent", () => {
    expect(getMagneticTargetState(0.7).bend).toBe(0);
  });

  it("bends and shrinks the core near impact", () => {
    const state = getMagneticTargetState(0.94);
    expect(state.bend).toBeGreaterThan(0);
    expect(state.coreScale).toBeLessThan(1);
  });

  it("creates a short ripple only after impact", () => {
    expect(getMagneticTargetState(1).rippleOpacity).toBeGreaterThan(0);
    expect(getMagneticTargetState(1.4).rippleOpacity).toBe(0);
  });
});
