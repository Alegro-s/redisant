import { useState, type ReactNode } from 'react';

type PreviewTab = 'projects' | 'editor' | 'chat' | 'engine' | 'build';

const NAV: { id: PreviewTab; label: string }[] = [
  { id: 'projects', label: 'Проекты' },
  { id: 'editor', label: 'Редактор' },
  { id: 'chat', label: 'Чат' },
  { id: 'engine', label: 'Движок' },
  { id: 'build', label: 'Сборка' },
];

const PANELS: Record<
  PreviewTab,
  { kicker: string; hint: string; render: () => ReactNode }
> = {
  projects: {
    kicker: 'Проекты · облако · локально',
    hint: 'Карточки игр — открыть в редакторе или Play',
    render: () => (
      <ul className="lynx-launcher-ws-list">
        <li>
          <strong>lynx-tetris</strong>
          <span>2D · Lua</span>
        </li>
        <li>
          <strong>platformer-demo</strong>
          <span>облако</span>
        </li>
        <li className="lynx-launcher-ws-list-add">+ Новый проект</li>
      </ul>
    ),
  },
  editor: {
    kicker: 'Сцена · Lua · Box2D',
    hint: 'Редактор сцен, тайлмапы и скрипты',
    render: () => (
      <div className="lynx-launcher-ws-grid">
        <span />
        <span />
        <span />
        <span />
      </div>
    ),
  },
  chat: {
    kicker: 'Мессенджер · Lynx',
    hint: 'Личные и групповые чаты в Launcher',
    render: () => (
      <div className="lynx-launcher-ws-chat">
        <div className="lynx-launcher-chat-in">Привет! Сцена готова к Play?</div>
        <div className="lynx-launcher-chat-out">Да, залей билд в аркаду</div>
        <div className="lynx-launcher-chat-in">Ок, запускаю сборку…</div>
      </div>
    ),
  },
  engine: {
    kicker: 'Install Hub · ядро',
    hint: 'Скачать и обновить .lynxengine с Hub',
    render: () => (
      <ul className="lynx-launcher-ws-list">
        <li>
          <strong>lynx-engine 0.15.0</strong>
          <span className="lynx-launcher-tag-ok">stable</span>
        </li>
        <li>
          <strong>Рекомендуется</strong>
          <span>CDN · Hub</span>
        </li>
        <li className="lynx-launcher-ws-list-cta">Установить / обновить</li>
      </ul>
    ),
  },
  build: {
    kicker: 'Экспорт · релиз',
    hint: 'Windows, Android, Web и .lynxcart',
    render: () => (
      <div className="lynx-launcher-ws-build">
        <span>Windows EXE</span>
        <span>Android APK</span>
        <span>Web export</span>
        <span className="lynx-launcher-ws-build-active">.lynxcart → Arcade</span>
      </div>
    ),
  },
};

/** Интерактивный макет окна Launcher на главной Hub. */
export function LynxLauncherPreview() {
  const [tab, setTab] = useState<PreviewTab>('projects');
  const panel = PANELS[tab];

  return (
    <div className="lynx-launcher-frame">
      <div className="lynx-launcher-titlebar">
        <span className="lynx-launcher-dot" />
        <span className="lynx-launcher-dot" />
        <span className="lynx-launcher-dot" />
        <span className="lynx-launcher-title">Lynx Launcher</span>
      </div>
      <div className="lynx-launcher-body">
        <nav className="lynx-launcher-nav" aria-label="Разделы Launcher (демо)">
          {NAV.map((item) => (
            <button
              key={item.id}
              type="button"
              className={tab === item.id ? 'is-active' : undefined}
              onClick={() => setTab(item.id)}
            >
              {item.label}
            </button>
          ))}
        </nav>
        <div className="lynx-launcher-workspace" key={tab}>
          <p className="lynx-launcher-ws-label">{panel.kicker}</p>
          {panel.render()}
          <p className="lynx-launcher-ws-hint">{panel.hint}</p>
        </div>
      </div>
    </div>
  );
}
