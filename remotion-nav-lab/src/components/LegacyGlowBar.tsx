type LegacyGlowBarProps = {
  page: number;
};

export const LegacyGlowBar: React.FC<LegacyGlowBarProps> = ({page}) => (
  <div
    className="legacy-glow-bar"
    style={{translate: `${page * 84}px 0`}}
  >
    <span />
  </div>
);
