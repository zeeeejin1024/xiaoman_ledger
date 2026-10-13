import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

describe("Remotion markup", () => {
  it("contains no CSS keyframes or animation declarations", () => {
    const css = readFileSync(new URL("./index.css", import.meta.url), "utf8");
    expect(css).not.toMatch(/@keyframes|animation\s*:/);
  });

  it("registers the liquid glass trail preview", () => {
    const source = readFileSync(
      new URL("./Composition.tsx", import.meta.url),
      "utf8",
    );
    expect(source).toContain("LiquidGlassTrailPreview");
  });

  it("uses liquid-glass-react for the magnetic target", () => {
    const source = readFileSync(
      new URL("./components/LiquidGlassTarget.tsx", import.meta.url),
      "utf8",
    );
    expect(source).toContain('from "liquid-glass-react"');
    expect(source).toContain("<LiquidGlass");
  });

  it("removes meteor dots, lines, particles, and afterimages", () => {
    const scene = readFileSync(
      new URL("./components/NavigationScene.tsx", import.meta.url),
      "utf8",
    );
    const styles = readFileSync(
      new URL("./index.css", import.meta.url),
      "utf8",
    );

    expect(scene).not.toContain("MeteorTrail");
    expect(scene).toContain("LiquidGlassSmear");
    expect(styles).not.toContain("meteor-svg");
    expect(styles).not.toMatch(/border-radius:\s*50%/);
  });
});
