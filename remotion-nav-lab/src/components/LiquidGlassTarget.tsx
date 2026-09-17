import LiquidGlass from "liquid-glass-react";
import type {MagneticTargetState} from "../motion/types";

type LiquidGlassTargetProps = {
  targetPage: number;
  direction: number;
  magnetic: MagneticTargetState;
};

export const LiquidGlassTarget: React.FC<LiquidGlassTargetProps> = ({
  targetPage,
  direction,
  magnetic,
}) => (
  <div
    className="liquid-glass-target"
    style={{translate: `${targetPage * 84}px 0`}}
  >
    <LiquidGlass
      displacementScale={28 + magnetic.bend * 1.8}
      blurAmount={0.055}
      saturation={150}
      aberrationIntensity={1.4 + magnetic.bend * 0.04}
      elasticity={0.22}
      cornerRadius={18}
      padding="0"
      mode="standard"
      globalMousePos={{x: 1, y: 1}}
      mouseOffset={{x: direction * (8 + magnetic.bend), y: -magnetic.bend * 0.45}}
      style={{
        position: "absolute",
        left: 42,
        top: 25,
        opacity: 0.76 + magnetic.rippleOpacity * 0.55,
      }}
    >
      <div className="liquid-glass-target-content" />
    </LiquidGlass>
  </div>
);
