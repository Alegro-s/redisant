/** Изометрия в духе Gemini: устройство + плитки модулей + линии данных */
export function LynxIsometricVisual() {
  return (
    <div className="lynx-iso-wrap" aria-hidden>
      <svg viewBox="0 0 480 420" className="lynx-iso-svg">
        <defs>
          <linearGradient id="lynx-tile-a" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#60a5fa" />
            <stop offset="100%" stopColor="#1d4ed8" />
          </linearGradient>
          <linearGradient id="lynx-tile-b" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#818cf8" />
            <stop offset="100%" stopColor="#4338ca" />
          </linearGradient>
          <linearGradient id="lynx-tile-c" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#38bdf8" />
            <stop offset="100%" stopColor="#0369a1" />
          </linearGradient>
          <linearGradient id="lynx-tile-d" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#a78bfa" />
            <stop offset="100%" stopColor="#6d28d9" />
          </linearGradient>
          <linearGradient id="lynx-line-grad" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stopColor="#60a5fa" stopOpacity="0.2" />
            <stop offset="50%" stopColor="#93c5fd" />
            <stop offset="100%" stopColor="#c084fc" stopOpacity="0.2" />
          </linearGradient>
          <filter id="lynx-glow" x="-40%" y="-40%" width="180%" height="180%">
            <feGaussianBlur stdDeviation="6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>

        {/* фон панели */}
        <rect x="24" y="16" width="432" height="388" rx="28" fill="rgba(8, 14, 28, 0.55)" stroke="rgba(96, 165, 250, 0.12)" />

        {/* устройство (изометрия) */}
        <g transform="translate(240 310)">
          <path
            d="M-88 8 L0 -42 L88 8 L88 52 L0 102 L-88 52 Z"
            fill="none"
            stroke="rgba(96, 165, 250, 0.35)"
            strokeWidth="1.5"
          />
          <path d="M-72 16 L0 -28 L72 16 L72 44 L0 88 L-72 44 Z" fill="rgba(15, 23, 42, 0.8)" stroke="rgba(147, 197, 253, 0.25)" />
          <rect x="-48" y="4" width="96" height="56" rx="6" fill="rgba(30, 58, 138, 0.35)" stroke="rgba(96, 165, 250, 0.2)" />
        </g>

        {/* линии к плиткам */}
        <path d="M240 268 Q200 220 148 168" fill="none" stroke="url(#lynx-line-grad)" strokeWidth="1.5" className="lynx-iso-line" />
        <path d="M240 268 Q280 220 332 168" fill="none" stroke="url(#lynx-line-grad)" strokeWidth="1.5" className="lynx-iso-line delay" />
        <path d="M240 268 Q200 200 148 248" fill="none" stroke="url(#lynx-line-grad)" strokeWidth="1.5" className="lynx-iso-line delay2" />
        <path d="M240 268 Q280 200 332 248" fill="none" stroke="url(#lynx-line-grad)" strokeWidth="1.5" className="lynx-iso-line delay3" />
        <path d="M240 268 L240 200" fill="none" stroke="#93c5fd" strokeWidth="1.5" opacity="0.6" className="lynx-iso-line" />

        {/* акцентные искры */}
        <line x1="168" y1="140" x2="168" y2="118" stroke="#fbbf24" strokeWidth="1.5" opacity="0.7" className="lynx-iso-spark" />
        <line x1="312" y1="220" x2="330" y2="210" stroke="#4ade80" strokeWidth="1.5" opacity="0.7" className="lynx-iso-spark delay" />
        <line x1="128" y1="260" x2="110" y2="252" stroke="#f87171" strokeWidth="1.5" opacity="0.6" className="lynx-iso-spark delay2" />

        {/* плитки 2×2 */}
        <g filter="url(#lynx-glow)">
          <g transform="translate(108 108)">
            <rect width="72" height="72" rx="16" fill="url(#lynx-tile-a)" />
            <text x="36" y="40" textAnchor="middle" fill="#eff6ff" fontSize="11" fontWeight="600" fontFamily="system-ui">
              Сцены
            </text>
          </g>
          <g transform="translate(300 108)">
            <rect width="72" height="72" rx="16" fill="url(#lynx-tile-b)" />
            <text x="36" y="40" textAnchor="middle" fill="#eff6ff" fontSize="11" fontWeight="600" fontFamily="system-ui">
              Физика
            </text>
          </g>
          <g transform="translate(108 220)">
            <rect width="72" height="72" rx="16" fill="url(#lynx-tile-c)" />
            <text x="36" y="40" textAnchor="middle" fill="#eff6ff" fontSize="11" fontWeight="600" fontFamily="system-ui">
              Lua
            </text>
          </g>
          <g transform="translate(300 220)">
            <rect width="72" height="72" rx="16" fill="url(#lynx-tile-d)" />
            <text x="36" y="40" textAnchor="middle" fill="#eff6ff" fontSize="11" fontWeight="600" fontFamily="system-ui">
              Сборка
            </text>
          </g>
        </g>

        {/* подпись Launcher */}
        <text x="240" y="382" textAnchor="middle" fill="rgba(148, 163, 184, 0.9)" fontSize="11" fontFamily="system-ui" letterSpacing="0.08em">
          LYNX LAUNCHER
        </text>
      </svg>
    </div>
  );
}
