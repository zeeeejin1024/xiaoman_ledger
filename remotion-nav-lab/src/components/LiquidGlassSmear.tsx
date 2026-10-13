type LiquidGlassSmearProps = {
  page: number;
  velocity: number;
};

export const LiquidGlassSmear: React.FC<LiquidGlassSmearProps> = ({
  page,
  velocity,
}) => {
  const strength = Math.min(1, Math.abs(velocity) * 34);
  const direction = velocity < 0 ? -1 : 1;
  const center = 42 + page * 84;
  const offset = direction * strength * -17;

  return (
    <div
      className="liquid-glass-smear"
      style={{
        opacity: strength * 0.64,
        transform: `translate3d(${center - 48 + offset}px, 0, 0) scaleX(${0.72 + strength * 0.52})`,
        transformOrigin: direction > 0 ? "right center" : "left center",
      }}
    />
  );
};
