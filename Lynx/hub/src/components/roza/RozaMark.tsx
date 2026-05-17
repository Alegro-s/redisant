/** Фирменные знаки Roza — светлая линейка Google */
export function RozaMark({ variant, size = 40 }: { variant: 'brand' | 'ai' | 'os'; size?: number }) {
  if (variant === 'ai') {
    const id = `roza-gemini-${size}`;
    return (
      <svg width={size} height={size} viewBox="0 0 48 48" aria-hidden className="roza-mark roza-mark-ai">
        <defs>
          <linearGradient id={`${id}-a`} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#4285f4" />
            <stop offset="35%" stopColor="#9b72f2" />
            <stop offset="70%" stopColor="#d96570" />
            <stop offset="100%" stopColor="#f4b400" />
          </linearGradient>
        </defs>
        <circle cx="24" cy="24" r="22" fill="#f8f9fa" />
        <circle cx="24" cy="24" r="20" fill="none" stroke={`url(#${id}-a)`} strokeWidth="3" />
        <path
          fill={`url(#${id}-a)`}
          d="M24 10c1.2 4.5 4.5 7.8 9 9-4.5 1.2-7.8 4.5-9 9-1.2-4.5-4.5-7.8-9-9 4.5-1.2 7.8-4.5 9-9z"
        />
      </svg>
    );
  }
  if (variant === 'os') {
    return (
      <span
        className="roza-mark-os-text"
        style={{ fontSize: size * 0.42, lineHeight: 1 }}
        aria-hidden
      >
        ROZA<span>OS</span>
      </span>
    );
  }
  return null;
}
