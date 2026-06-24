import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  ENGINE_MANIFEST_URL,
  ENGINE_MANIFEST_CDN_URL,
  ENGINE_WEB_DEMO_URL,
  LYNX_LAUNCHER_EXE_URL,
  LYNX_LAUNCHER_APK_URL,
  LYNX_SOURCES_ZIP_URL,
} from '../config/links';
import {
  fetchEngineManifest,
  windowsEnginePackUrl,
  type EngineManifest,
} from '../lib/engineManifest';

const platforms = [
  {
    key: 'win',
    icon: 'Win',
    title: 'Windows',
    sub: 'EXE · установщик или portable',
    ready: Boolean(LYNX_LAUNCHER_EXE_URL),
    href: LYNX_LAUNCHER_EXE_URL,
  },
  {
    key: 'apk',
    icon: 'APK',
    title: 'Android',
    sub: 'Сборка вне магазинов',
    ready: Boolean(LYNX_LAUNCHER_APK_URL),
    href: LYNX_LAUNCHER_APK_URL,
  },
  {
    key: 'zip',
    icon: 'Src',
    title: 'Исходники',
    sub: 'ZIP клиента Launcher',
    ready: Boolean(LYNX_SOURCES_ZIP_URL),
    href: LYNX_SOURCES_ZIP_URL,
  },
];

export function DownloadPage() {
  const [manifest, setManifest] = useState<EngineManifest | null>(null);

  useEffect(() => {
    void fetchEngineManifest(ENGINE_MANIFEST_URL || ENGINE_MANIFEST_CDN_URL).then(setManifest);
  }, []);

  const enginePack = windowsEnginePackUrl(manifest);
  const recommended = manifest?.recommended_version ?? '—';

  return (
    <div className="lynx-dl-page">
      <p className="lynx-pill">Lynx Launcher</p>
      <h1>Загрузки клиента</h1>
      <p className="lynx-dl-lead">
        Лаунчер объединяет проекты, редактор, чат, движок и сборку. Рекомендуемая версия Engine:{' '}
        <strong>{recommended}</strong>. Установка через Install Hub в Launcher или пакет .lynxengine ниже.
      </p>

      <div className="lynx-dl-platforms">
        {platforms.map((p) => (
          <article key={p.key} className="lynx-dl-platform">
            <span className="lynx-dl-platform-icon">{p.icon}</span>
            <div>
              <h2>{p.title}</h2>
              <p>{p.sub}</p>
            </div>
            {p.ready && p.href ? (
              <a href={p.href} className="lynx-dl-platform-action is-btn" target="_blank" rel="noreferrer">
                Скачать
              </a>
            ) : (
              <span className="lynx-dl-platform-action">Скоро будет</span>
            )}
          </article>
        ))}
      </div>

      <section className="lynx-dl-engine-section">
        <h2>Lynx Engine</h2>
        {enginePack ? (
          <p>
            Windows pack:{' '}
            <a href={enginePack} className="lynx-launch-row-action" target="_blank" rel="noreferrer">
              скачать .lynxengine
            </a>
          </p>
        ) : (
          <p className="lynx-launch-muted">Пакет движка появится после публикации манифеста.</p>
        )}
        <p>
          <a href={ENGINE_WEB_DEMO_URL} className="lynx-launch-row-action">
            Открыть редактор в браузере →
          </a>
        </p>
      </section>

      <p className="lynx-dl-note-line">
        Манифест:{' '}
        <a href={ENGINE_MANIFEST_CDN_URL} target="_blank" rel="noreferrer" className="lynx-launch-row-action">
          CDN JSON
        </a>
        {ENGINE_MANIFEST_URL ? (
          <>
            {' · '}
            <a href={ENGINE_MANIFEST_URL} target="_blank" rel="noreferrer" className="lynx-launch-row-action">
              API
            </a>
          </>
        ) : null}
        {' · '}
        <Link to="/">Главная Hub</Link>
      </p>

      <p className="lynx-launch-foot" style={{ marginTop: '2rem' }}>
        <Link to="/">← Главная</Link>
      </p>
    </div>
  );
}
