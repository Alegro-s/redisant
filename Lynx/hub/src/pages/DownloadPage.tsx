import { Link } from 'react-router-dom';
import {
  ENGINE_MANIFEST_URL,
  LYNX_LAUNCHER_EXE_URL,
  LYNX_LAUNCHER_APK_URL,
  LYNX_SOURCES_ZIP_URL,
} from '../config/links';

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
  return (
    <div className="lynx-dl-page">
      <p className="lynx-pill">Lynx Launcher</p>
      <h1>Загрузки клиента</h1>
      <p className="lynx-dl-lead">
        Лаунчер объединяет проекты, редактор, чат, движок и сборку. Ядро Lynx Core бесплатно; версии и changelog
        публикуются на Hub после выхода релизов.
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

      <p className="lynx-dl-note-line">
        {ENGINE_MANIFEST_URL ? (
          <>
            Манифест движка:{' '}
            <a href={ENGINE_MANIFEST_URL} target="_blank" rel="noreferrer" className="lynx-launch-row-action">
              открыть
            </a>
          </>
        ) : (
          <>Манифест движка — скоро будет.</>
        )}
        {' · '}
        Новости и версии Core — в <Link to="/">разделах Hub</Link> после публикации.
      </p>

      <p className="lynx-launch-foot" style={{ marginTop: '2rem' }}>
        <Link to="/">← Главная</Link>
      </p>
    </div>
  );
}
