/** Статичный макет окна Launcher — без свечений и схем */
export function LynxLauncherPreview() {
  const nav = [
    { id: 'projects', label: 'Проекты' },
    { id: 'editor', label: 'Редактор' },
    { id: 'chat', label: 'Чат' },
    { id: 'engine', label: 'Движок', active: true },
    { id: 'build', label: 'Сборка' },
  ];

  return (
    <div className="lynx-launcher-frame" aria-hidden>
      <div className="lynx-launcher-titlebar">
        <span className="lynx-launcher-dot" />
        <span className="lynx-launcher-dot" />
        <span className="lynx-launcher-dot" />
        <span className="lynx-launcher-title">Lynx Launcher</span>
      </div>
      <div className="lynx-launcher-body">
        <nav className="lynx-launcher-nav">
          {nav.map((item) => (
            <span key={item.id} className={item.active ? 'is-active' : undefined}>
              {item.label}
            </span>
          ))}
        </nav>
        <div className="lynx-launcher-workspace">
          <p className="lynx-launcher-ws-label">Сцена · Lua · Box2D</p>
          <div className="lynx-launcher-ws-grid">
            <span />
            <span />
            <span />
            <span />
          </div>
          <p className="lynx-launcher-ws-hint">Один клиент — движок, ИИ-чат и сборка</p>
        </div>
      </div>
    </div>
  );
}
