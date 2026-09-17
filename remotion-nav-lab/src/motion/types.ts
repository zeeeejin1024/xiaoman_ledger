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

export type TrailPoint = {
  x: number;
  y: number;
  opacity: number;
  radius: number;
};

export type MeteorVisual = {
  headX: number;
  headY: number;
  stretch: number;
  tailLength: number;
  history: TrailPoint[];
  afterimages: TrailPoint[];
  motes: TrailPoint[];
};

export type MagneticTargetState = {
  bend: number;
  coreScale: number;
  iconScaleX: number;
  iconScaleY: number;
  rippleOpacity: number;
  rippleScale: number;
};
