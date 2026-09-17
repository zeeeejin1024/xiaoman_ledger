import type {GesturePhase, GestureSample} from "./types";

const clamp = (value: number, min: number, max: number) =>
  Math.min(max, Math.max(min, value));

const smoothstep = (value: number) => {
  const t = clamp(value, 0, 1);
  return t * t * (3 - 2 * t);
};

const segment = (
  frame: number,
  startFrame: number,
  endFrame: number,
  from: number,
  to: number,
) => from + (to - from) * smoothstep((frame - startFrame) / (endFrame - startFrame));

const getPageAtFrame = (frame: number) => {
  if (frame <= 14) return 0;
  if (frame <= 64) return segment(frame, 15, 64, 0, 0.82);
  if (frame <= 99) return segment(frame, 65, 99, 0.82, 1.98);
  if (frame <= 112) return segment(frame, 100, 112, 1.98, 2.12);
  if (frame <= 139) return segment(frame, 113, 139, 2.12, 1.18);
  if (frame <= 209) return segment(frame, 140, 209, 1.18, 1);
  return 1;
};

const getPhase = (frame: number): GesturePhase => {
  if (frame <= 14) return "idle";
  if (frame <= 64) return "slow-drag";
  if (frame <= 99) return "fling";
  if (frame <= 139) return "reverse";
  return "settle";
};

export const getGestureSample = (frame: number, fps: number): GestureSample => {
  const safeFrame = Math.max(0, frame);
  const page = clamp(getPageAtFrame(safeFrame), 0, 4);
  const previousPage = clamp(getPageAtFrame(Math.max(0, safeFrame - 1)), 0, 4);
  const phase = getPhase(safeFrame);

  return {
    page,
    velocity: (page - previousPage) * (30 / Math.max(1, fps)),
    targetPage: phase === "reverse" || phase === "settle" ? 1 : Math.min(4, Math.ceil(page)),
    phase,
    isDragging: phase === "slow-drag" || phase === "reverse",
  };
};
