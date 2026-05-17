/** Схема устройства Lynx — статичная зарисовка без «волны» */
export function LynxEngineStack() {
  return (
    <div className="lynx-stack-diagram" aria-hidden>
      <svg viewBox="0 0 420 360" className="lynx-stack-svg">
        <defs>
          <linearGradient id="lynx-stack-g1" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#7c3aed" />
            <stop offset="100%" stopColor="#312e81" />
          </linearGradient>
          <linearGradient id="lynx-stack-g2" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor="#c084fc" />
            <stop offset="100%" stopColor="#6d28d9" />
          </linearGradient>
          <linearGradient id="lynx-stack-g3" x1="0%" y1="100%" x2="100%" y2="0%">
            <stop offset="0%" stopColor="#134e4a" />
            <stop offset="100%" stopColor="#22c55e" />
          </linearGradient>
        </defs>
        {/* Launcher */}
        <rect x="40" y="24" width="340" height="72" rx="14" fill="url(#lynx-stack-g1)" opacity="0.95" />
        <text x="210" y="52" textAnchor="middle" fill="#f0f6fc" fontSize="13" fontWeight="600" fontFamily="system-ui">
          Lynx Launcher
        </text>
        <text x="210" y="72" textAnchor="middle" fill="#d8b4fe" fontSize="10" fontFamily="system-ui">
          Редактор · каталог · синхронизация
        </text>
        <path d="M210 96 L210 118" stroke="#c084fc" strokeWidth="2" strokeDasharray="4 3" />
        {/* Core */}
        <rect x="24" y="118" width="372" height="140" rx="16" fill="url(#lynx-stack-g2)" opacity="0.92" />
        <text x="210" y="148" textAnchor="middle" fill="#fff" fontSize="14" fontWeight="600" fontFamily="system-ui">
          Lynx Core
        </text>
        <rect x="48" y="162" width="96" height="44" rx="8" fill="rgba(255,255,255,0.12)" />
        <text x="96" y="182" textAnchor="middle" fill="#e9d5ff" fontSize="10" fontFamily="system-ui">
          Сцены
        </text>
        <text x="96" y="196" textAnchor="middle" fill="#c4b5fd" fontSize="9" fontFamily="system-ui">
          2D · UI
        </text>
        <rect x="162" y="162" width="96" height="44" rx="8" fill="rgba(255,255,255,0.12)" />
        <text x="210" y="182" textAnchor="middle" fill="#e9d5ff" fontSize="10" fontFamily="system-ui">
          Физика
        </text>
        <text x="210" y="196" textAnchor="middle" fill="#c4b5fd" fontSize="9" fontFamily="system-ui">
          Box2D
        </text>
        <rect x="276" y="162" width="96" height="44" rx="8" fill="rgba(255,255,255,0.12)" />
        <text x="324" y="182" textAnchor="middle" fill="#e9d5ff" fontSize="10" fontFamily="system-ui">
          Lua
        </text>
        <text x="324" y="196" textAnchor="middle" fill="#c4b5fd" fontSize="9" fontFamily="system-ui">
          Скрипты
        </text>
        <path d="M210 258 L210 278" stroke="#c084fc" strokeWidth="2" strokeDasharray="4 3" />
        {/* Build */}
        <rect x="56" y="278" width="308" height="58" rx="12" fill="url(#lynx-stack-g3)" opacity="0.95" />
        <text x="210" y="302" textAnchor="middle" fill="#ecfdf5" fontSize="12" fontWeight="600" fontFamily="system-ui">
          Сборка
        </text>
        <text x="210" y="320" textAnchor="middle" fill="#a7f3d0" fontSize="10" fontFamily="system-ui">
          Windows · Linux · Android
        </text>
      </svg>
    </div>
  );
}
