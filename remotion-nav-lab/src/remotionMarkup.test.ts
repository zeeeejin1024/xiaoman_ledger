import {readFileSync} from "node:fs";
import {describe, expect, it} from "vitest";

describe("Remotion markup", () => {
  it("contains no CSS keyframes or animation declarations", () => {
    const css = readFileSync(new URL("./index.css", import.meta.url), "utf8");
    expect(css).not.toMatch(/@keyframes|animation\s*:/);
  });

  it("registers the magnetic comparison composition", () => {
    const source = readFileSync(
      new URL("./Composition.tsx", import.meta.url),
      "utf8",
    );
    expect(source).toContain("MagneticMeteorComparison");
  });
});
