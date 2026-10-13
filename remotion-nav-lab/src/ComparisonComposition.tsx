import { useCurrentFrame, useVideoConfig } from "remotion";
import { NavigationScene } from "./components/NavigationScene";
import { getGestureSample } from "./motion/gestureTimeline";

const phaseLabel = {
  idle: "静止",
  "slow-drag": "慢速跟手",
  fling: "快速甩动",
  reverse: "途中反向",
  settle: "自然收束",
} as const;

export const LiquidGlassTrailPreview: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const sample = getGestureSample(frame, fps);

  return (
    <main className="comparison-stage">
      <header className="comparison-header">
        <div>
          <small>XIAOMAN · MOTION STUDY</small>
          <h1>拖影是底托的延伸，不是另一颗流星</h1>
        </div>
        <div className="phase-pill">{phaseLabel[sample.phase]}</div>
      </header>
      <p className="comparison-copy">
        页面与玻璃底托读取同一个连续进度。拖动时间轴可检查慢拖、快甩、反向和停止，过程中不会出现小圆点。
      </p>
      <div className="preview-stage">
        <NavigationScene />
      </div>
      <footer className="timeline-legend">
        <span>0–14 静止</span>
        <span>15–64 慢拖</span>
        <span>65–99 快甩</span>
        <span>100–139 反向</span>
        <span>140–209 收束</span>
      </footer>
    </main>
  );
};
