import LiquidGlass from "liquid-glass-react";

type LiquidGlassTargetProps = {
  page: number;
  velocity: number;
};

export const LiquidGlassTarget: React.FC<LiquidGlassTargetProps> = ({
  page,
  velocity,
}) => {
  const strength = Math.min(1, Math.abs(velocity) * 30);
  const direction = velocity < 0 ? -1 : 1;

  return (
    <div
      className="liquid-glass-target"
      style={{
        transform: `translate3d(${page * 84}px, 0, 0) scaleX(${1 + strength * 0.08})`,
      }}
    >
      <LiquidGlass
        displacementScale={24 + strength * 8}
        blurAmount={0.05}
        saturation={145}
        aberrationIntensity={1.1 + strength * 0.45}
        elasticity={0.18}
        cornerRadius={18}
        padding="0"
        mode="standard"
        globalMousePos={{ x: 1, y: 1 }}
        mouseOffset={{ x: direction * strength * 11, y: 0 }}
        style={{
          position: "absolute",
          left: 15,
          top: 13,
          opacity: 0.82,
        }}
      >
        <div className="liquid-glass-target-content" />
      </LiquidGlass>
    </div>
  );
};
