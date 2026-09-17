import type {GestureSample, MeteorVisual, TrailPoint} from "./types";

const clamp = (value: number, min: number, max: number) =>
  Math.min(max, Math.max(min, value));

const point = (
  headX: number,
  headY: number,
  direction: number,
  distance: number,
  progress: number,
  opacity: number,
  radius: number,
): TrailPoint => ({
  x: headX - direction * distance * progress,
  y: headY + Math.sin(progress * Math.PI) * 2.4 * direction,
  opacity,
  radius,
});

export const buildMeteorVisual = (
  sample: GestureSample,
  tabWidth: number,
): MeteorVisual => {
  const speed = Math.abs(sample.velocity);
  const normalizedSpeed = clamp(speed / 0.04, 0, 1);
  const direction = sample.velocity < 0 ? -1 : 1;
  const tailLength = 18 + normalizedSpeed * Math.min(83, tabWidth * 0.94);
  const headX = tabWidth * (sample.page + 0.5);
  const headY = 25;
  const historyCount = Math.round(8 + normalizedSpeed * 6);

  const history = Array.from({length: historyCount}, (_, index) => {
    const progress = (index + 1) / historyCount;
    return point(
      headX,
      headY,
      direction,
      tailLength,
      progress,
      Math.pow(1 - progress, 1.35) * (0.86 + normalizedSpeed * 0.12),
      2.6 - progress * 1.65,
    );
  });

  const afterimageCount = speed < 0.018 ? 0 : speed > 0.034 ? 3 : 2;
  const afterimages = Array.from({length: afterimageCount}, (_, index) => {
    const progress = (index + 1) / (afterimageCount + 2);
    return point(
      headX,
      headY,
      direction,
      tailLength * 0.72,
      progress,
      0.34 - index * 0.075,
      3.4 - index * 0.45,
    );
  });

  const moteCount = speed < 0.022 ? 0 : speed > 0.035 ? 3 : 2;
  const motes = Array.from({length: moteCount}, (_, index) => {
    const progress = (index + 1) / (moteCount + 1);
    const base = point(
      headX,
      headY,
      direction,
      tailLength * 0.88,
      progress,
      0.54 - index * 0.1,
      1.25 - index * 0.12,
    );
    return {
      ...base,
      y: base.y + (index % 2 === 0 ? -5.5 : 6.5),
    };
  });

  return {
    headX,
    headY,
    stretch: 1 + normalizedSpeed * 0.62,
    tailLength,
    history,
    afterimages,
    motes,
  };
};
