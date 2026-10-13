import { Composition } from "remotion";
import { LiquidGlassTrailPreview } from "./ComparisonComposition";

export const MyComposition: React.FC = () => (
  <Composition
    id="LiquidGlassTrailPreview"
    component={LiquidGlassTrailPreview}
    durationInFrames={210}
    fps={30}
    width={960}
    height={720}
  />
);
