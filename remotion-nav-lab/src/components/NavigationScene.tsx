import {useCurrentFrame, useVideoConfig} from "remotion";
import {getGestureSample} from "../motion/gestureTimeline";
import {getMagneticTargetState} from "../motion/magneticTarget";
import {buildMeteorVisual} from "../motion/meteorHistory";
import {LegacyGlowBar} from "./LegacyGlowBar";
import {LiquidGlassTarget} from "./LiquidGlassTarget";
import {MeteorTrail} from "./MeteorTrail";

type NavigationSceneProps = {
  variant: "legacy" | "magnetic";
};

const pages = [
  {title: "首页", amount: "¥ 3,280", copy: "今天也留一点余地", tone: "#447fe8"},
  {title: "报告", amount: "省下 ¥286", copy: "本周节奏比上周更稳", tone: "#4b987f"},
  {title: "统计", amount: "餐饮 38%", copy: "支出结构正在变清晰", tone: "#7b67ba"},
  {title: "通知", amount: "2 条", copy: "预算与账单提醒", tone: "#c27b4a"},
  {title: "我的", amount: "连续 12 天", copy: "你的记账习惯正在形成", tone: "#4a6378"},
];

const navItems = [
  {icon: "⌂", label: "首页"},
  {icon: "◔", label: "报告"},
  {icon: "◫", label: "统计"},
  {icon: "◌", label: "通知"},
  {icon: "◉", label: "我的"},
];

export const NavigationScene: React.FC<NavigationSceneProps> = ({variant}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const sample = getGestureSample(frame, fps);
  const visual = buildMeteorVisual(sample, 84);
  const targetDistance = Math.abs(sample.targetPage - sample.page);
  const attractionProgress = sample.phase === "idle" ? 0 : 1 - Math.min(1, targetDistance);
  const magnetic = getMagneticTargetState(attractionProgress);
  const selected = Math.max(0, Math.min(4, Math.round(sample.page)));
  const direction = sample.velocity < 0 ? -1 : 1;

  return (
    <section className={`phone-scene ${variant}`}>
      <div className="phone-label">
        <strong>{variant === "legacy" ? "旧方案" : "磁吸流星"}</strong>
        <span>{variant === "legacy" ? "固定发光条" : "速度历史 + 磁吸落点"}</span>
      </div>
      <div className="phone-frame">
        <div className="phone-island" />
        <div className="phone-status"><span>9:41</span><span className="status-icons">▮▮▮<b>⌁</b>▰</span></div>
        <div className="phone-heading"><small>9月17日 · 星期四</small><h2>小满记账</h2></div>
        <div className="page-window">
          <div className="page-strip" style={{translate: `${-sample.page * 420}px 0`}}>
            {pages.map((page) => (
              <article className="ledger-page" key={page.title}>
                <div className="balance-card" style={{background: `linear-gradient(145deg, ${page.tone}, ${page.tone}b8)`}}>
                  <span>{page.title}</span><b>{page.amount}</b><small>{page.copy}</small>
                </div>
                <div className="ledger-row"><i>●</i><div><b>今日记录</b><small>自动归类 · 已同步</small></div><em>-¥32.00</em></div>
                <div className="ledger-row"><i>◆</i><div><b>预算状态</b><small>本月仍有余地</small></div><em className="good">正常</em></div>
              </article>
            ))}
          </div>
        </div>
        <div className="bottom-nav">
          {variant === "magnetic" ? (
            <LiquidGlassTarget
              targetPage={sample.targetPage}
              direction={direction}
              magnetic={magnetic}
            />
          ) : null}
          <div className="motion-layer">
            {variant === "legacy" ? (
              <LegacyGlowBar page={sample.page} />
            ) : (
              <MeteorTrail visual={visual} magnetic={magnetic} color="#6f9fff" direction={direction} />
            )}
          </div>
          {navItems.map((item, index) => {
            const isTarget = index === sample.targetPage && variant === "magnetic";
            return (
              <div className={index === selected ? "nav-item selected" : "nav-item"} key={item.label}>
                <span
                  className="nav-icon"
                  style={{
                    scale: isTarget ? `${magnetic.iconScaleX} ${magnetic.iconScaleY}` : "1",
                  }}
                >{item.icon}</span>
                <small>{item.label}</small>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
};
