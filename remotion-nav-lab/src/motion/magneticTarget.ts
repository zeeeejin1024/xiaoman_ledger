import type {MagneticTargetState} from "./types";

const clamp = (value: number, min: number, max: number) =>
  Math.min(max, Math.max(min, value));

const smoothstep = (value: number) => {
  const t = clamp(value, 0, 1);
  return t * t * (3 - 2 * t);
};

export const getMagneticTargetState = (
  normalizedProgress: number,
): MagneticTargetState => {
  const attraction = smoothstep((normalizedProgress - 0.82) / 0.18);
  const impactAge = Math.max(0, normalizedProgress - 1);
  const rippleLife =
    normalizedProgress >= 1.4 ? 0 : clamp(1 - impactAge / 0.4, 0, 1);
  const compression = smoothstep((normalizedProgress - 0.9) / 0.1);
  const recovery = impactAge > 0 ? smoothstep(impactAge / 0.25) : 0;
  const activeCompression = compression * (1 - recovery);

  return {
    bend: attraction * 8,
    coreScale: 1 - attraction * 0.72,
    iconScaleX: 1 - activeCompression * 0.04,
    iconScaleY: 1 + activeCompression * 0.025,
    rippleOpacity: normalizedProgress >= 1 ? rippleLife * 0.32 : 0,
    rippleScale: normalizedProgress >= 1 ? 0.72 + (1 - rippleLife) * 0.85 : 0.72,
  };
};
