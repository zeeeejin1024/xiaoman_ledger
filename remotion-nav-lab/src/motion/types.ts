export type GesturePhase =
  | "idle"
  | "slow-drag"
  | "fling"
  | "reverse"
  | "settle";

export type GestureSample = {
  page: number;
  velocity: number;
  targetPage: number;
  phase: GesturePhase;
  isDragging: boolean;
};
