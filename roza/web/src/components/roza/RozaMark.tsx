/** Логотип Roza AI — ваш силуэт, заливка градиентом как у «искусственного интеллекта» */
function RozaAiMarkIcon({ size }: { size: number }) {
  return (
    <span
      className="roza-mark roza-mark-ai"
      style={{ width: size, height: size }}
      role="img"
      aria-label="Roza AI"
    />
  );
}

export function RozaMark({ variant, size = 40 }: { variant: 'brand' | 'ai' | 'os'; size?: number }) {
  if (variant === 'ai') {
    return <RozaAiMarkIcon size={size} />;
  }
  if (variant === 'os') {
    return (
      <span
        className="roza-mark-os-text roza-mark-os-badge"
        style={{ fontSize: Math.max(14, size * 0.38) }}
        aria-hidden
      >
        ROZA<span>OS</span>
      </span>
    );
  }
  return null;
}
