import {useCurrentFrame, useVideoConfig} from "remotion";
import {NavigationScene} from "./components/NavigationScene";
import {getGestureSample} from "./motion/gestureTimeline";

const phaseLabel = {
  idle: "静止",
  "slow-drag": "慢速跟手",
  fling: "快速甩动",
  reverse: "途中反向",
  settle: "磁吸落点",
} as const;

export const MagneticMeteorComparison: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const sample = getGestureSample(frame, fps);

  return (
    <main className="comparison-stage">
      <header className="comparison-header">
        <div><small>XIAOMAN · MOTION STUDY</small><h1>磁吸流星不是一条发光进度条</h1></div>
        <div className="phase-pill"><span />{phaseLabel[sample.phase]}</div>
      </header>
      <p className="comparison-copy">页面、能量核、时间尾迹和目标图标读取同一个运动进度。拖动时间轴观察慢拖、快甩、反向与吸收。</p>
      <div className="comparison-grid">
        <NavigationScene variant="legacy" />
        <NavigationScene variant="magnetic" />
      </div>
      <footer className="timeline-legend">
        <span>0–14 静止</span><span>15–64 慢拖</span><span>65–99 快甩</span><span>100–139 反向</span><span>140–209 吸附</span>
      </footer>
    </main>
  );
};
