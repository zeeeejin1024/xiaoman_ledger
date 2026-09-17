import {Composition} from "remotion";
import {MagneticMeteorComparison} from "./ComparisonComposition";

export const MyComposition: React.FC = () => (
  <Composition
    id="MagneticMeteorComparison"
    component={MagneticMeteorComparison}
    durationInFrames={210}
    fps={30}
    width={1280}
    height={720}
  />
);
