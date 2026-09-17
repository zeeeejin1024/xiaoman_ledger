import type {MagneticTargetState, MeteorVisual} from "../motion/types";

type MeteorTrailProps = {
  visual: MeteorVisual;
  magnetic: MagneticTargetState;
  color: string;
  direction: number;
};

const pathFromPoints = (visual: MeteorVisual, bend: number) => {
  const points = [...visual.history].reverse();
  const start = points[0] ?? {x: visual.headX, y: visual.headY};
  const segments = points
    .slice(1)
    .map((point) => `L ${point.x.toFixed(2)} ${point.y.toFixed(2)}`)
    .join(" ");
  return `M ${start.x.toFixed(2)} ${start.y.toFixed(2)} ${segments} L ${visual.headX.toFixed(2)} ${(visual.headY - bend).toFixed(2)}`;
};

export const MeteorTrail: React.FC<MeteorTrailProps> = ({
  visual,
  magnetic,
  color,
  direction,
}) => {
  const trailPath = pathFromPoints(visual, magnetic.bend);
  const coreWidth = 8 * visual.stretch * magnetic.coreScale;
  const coreHeight = 5 * magnetic.coreScale;
  const headY = visual.headY - magnetic.bend;

  return (
    <svg className="meteor-svg" viewBox="0 0 420 58" aria-hidden="true">
      <defs>
        <linearGradient
          id="meteor-tail-soft"
          x1={direction > 0 ? "0%" : "100%"}
          x2={direction > 0 ? "100%" : "0%"}
        >
          <stop offset="0%" stopColor={color} stopOpacity="0" />
          <stop offset="58%" stopColor={color} stopOpacity="0.24" />
          <stop offset="100%" stopColor="#ffffff" stopOpacity="0.82" />
        </linearGradient>
        <linearGradient
          id="meteor-tail-hot"
          x1={direction > 0 ? "0%" : "100%"}
          x2={direction > 0 ? "100%" : "0%"}
        >
          <stop offset="0%" stopColor={color} stopOpacity="0" />
          <stop offset="74%" stopColor={color} stopOpacity="0.66" />
          <stop offset="100%" stopColor="#ffffff" stopOpacity="1" />
        </linearGradient>
        <filter id="meteor-soft-glow" x="-40%" y="-200%" width="180%" height="500%">
          <feGaussianBlur stdDeviation="3.8" />
        </filter>
        <filter id="meteor-core-glow" x="-180%" y="-300%" width="460%" height="700%">
          <feGaussianBlur stdDeviation="2.8" result="blur" />
          <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>

      <path d={trailPath} fill="none" stroke="url(#meteor-tail-soft)" strokeWidth="9" strokeLinecap="round" filter="url(#meteor-soft-glow)" />
      {visual.history.map((historyPoint, index) => (
        <ellipse
          key={`history-${index}`}
          cx={historyPoint.x}
          cy={historyPoint.y}
          rx={historyPoint.radius * (0.8 + visual.stretch * 0.55)}
          ry={historyPoint.radius * 0.58}
          fill={color}
          opacity={historyPoint.opacity * 0.48}
          filter={index < 4 ? "url(#meteor-soft-glow)" : undefined}
        />
      ))}
      <path d={trailPath} fill="none" stroke="url(#meteor-tail-hot)" strokeWidth="2.6" strokeLinecap="round" />

      {visual.afterimages.map((afterimage, index) => (
        <ellipse
          key={`after-${index}`}
          cx={afterimage.x}
          cy={afterimage.y}
          rx={afterimage.radius * visual.stretch}
          ry={afterimage.radius * 0.55}
          fill={color}
          opacity={afterimage.opacity}
        />
      ))}

      {visual.motes.map((mote, index) => (
        <circle
          key={`mote-${index}`}
          cx={mote.x}
          cy={mote.y}
          r={mote.radius}
          fill="#f8fbff"
          opacity={mote.opacity}
          filter="url(#meteor-core-glow)"
        />
      ))}

      <circle
        cx={visual.headX}
        cy={visual.headY}
        r={13 * magnetic.rippleScale}
        fill="none"
        stroke={color}
        strokeWidth="1.4"
        opacity={magnetic.rippleOpacity}
      />
      <ellipse
        cx={visual.headX}
        cy={headY}
        rx={Math.max(0.6, coreWidth / 2)}
        ry={Math.max(0.4, coreHeight / 2)}
        fill="#ffffff"
        stroke={color}
        strokeWidth="1.2"
        filter="url(#meteor-core-glow)"
      />
    </svg>
  );
};
