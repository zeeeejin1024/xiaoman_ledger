import { useCurrentFrame, useVideoConfig } from "remotion";
import { getGestureSample } from "../motion/gestureTimeline";
import { LiquidGlassSmear } from "./LiquidGlassSmear";
import { LiquidGlassTarget } from "./LiquidGlassTarget";

const pages = [
  {
    title: "首页",
    amount: "¥ 3,280",
    copy: "今天也留一点余地",
    tone: "#447fe8",
  },
  {
    title: "报告",
    amount: "省下 ¥286",
    copy: "本周节奏比上周更稳",
    tone: "#4b987f",
  },
  {
    title: "统计",
    amount: "餐饮 38%",
    copy: "支出结构正在变清晰",
    tone: "#7b67ba",
  },
  { title: "通知", amount: "2 条", copy: "预算与账单提醒", tone: "#c27b4a" },
  {
    title: "我的",
    amount: "连续 12 天",
    copy: "你的记账习惯正在形成",
    tone: "#4a6378",
  },
];

const navItems = [
  { icon: "⌂", label: "首页" },
  { icon: "▥", label: "报告" },
  { icon: "▤", label: "统计" },
  { icon: "≡", label: "通知" },
  { icon: "♙", label: "我的" },
];

export const NavigationScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const sample = getGestureSample(frame, fps);
  const selected = Math.max(0, Math.min(4, Math.round(sample.page)));

  return (
    <section className="phone-scene liquid">
      <div className="phone-label">
        <strong>液态玻璃短拖影</strong>
        <span>
          没有独立头部、细线、圆点或粒子；速度只改变底托的轻微拉伸和柔和尾部。
        </span>
      </div>
      <div className="phone-frame">
        <div className="phone-island" />
        <div className="phone-status">
          <span>9:41</span>
          <span className="status-icons">
            ▮▮▮<b>⌁</b>▰
          </span>
        </div>
        <div className="phone-heading">
          <small>9月17日 · 星期四</small>
          <h2>小满记账</h2>
        </div>
        <div className="page-window">
          <div
            className="page-strip"
            style={{ translate: `${-sample.page * 420}px 0` }}
          >
            {pages.map((page) => (
              <article className="ledger-page" key={page.title}>
                <div
                  className="balance-card"
                  style={{
                    background: `linear-gradient(145deg, ${page.tone}, ${page.tone}b8)`,
                  }}
                >
                  <span>{page.title}</span>
                  <b>{page.amount}</b>
                  <small>{page.copy}</small>
                </div>
                <div className="ledger-row">
                  <i>●</i>
                  <div>
                    <b>今日记录</b>
                    <small>自动归类 · 已同步</small>
                  </div>
                  <em>-¥32.00</em>
                </div>
                <div className="ledger-row">
                  <i>◆</i>
                  <div>
                    <b>预算状态</b>
                    <small>本月仍有余地</small>
                  </div>
                  <em className="good">正常</em>
                </div>
              </article>
            ))}
          </div>
        </div>
        <div className="bottom-nav">
          <div className="motion-layer">
            <LiquidGlassSmear page={sample.page} velocity={sample.velocity} />
            <LiquidGlassTarget page={sample.page} velocity={sample.velocity} />
          </div>
          {navItems.map((item, index) => (
            <div
              className={index === selected ? "nav-item selected" : "nav-item"}
              key={item.label}
            >
              <span className="nav-icon">{item.icon}</span>
              <small>{item.label}</small>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};
