import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import '../styles/metric-public.css';
import { DESKTOP_INSTALLER_URL, LINKS } from './links';
import { usePageMeta } from '../hooks/usePageMeta';

type ReleaseManifest = {
  latest: string;
  channel: string;
  updated: string;
  downloads: {
    windows?: { url: string; filename: string; sha256?: string; size_mb?: number };
  };
  releases: { version: string; date: string; notes: string[] }[];
};

export function DesktopReleasesPage() {
  const [manifest, setManifest] = useState<ReleaseManifest | null>(null);
  const downloadUrl =
    import.meta.env.VITE_WAYPOINT_DESKTOP_URL ||
    manifest?.downloads?.windows?.url ||
    DESKTOP_INSTALLER_URL;

  usePageMeta({
    title: 'Релизы — Waypoint Desktop',
    description: 'Скачать Waypoint Desktop для Windows, история версий и changelog.',
    themeColor: '#1a2744',
  });

  useEffect(() => {
    fetch('/desktop-releases.json')
      .then((r) => r.json())
      .then(setManifest)
      .catch(() => null);
  }, []);

  return (
    <div className="metric-public">
      <header className="metric-nav">
        <Link to="/" className="metric-brand">
          <strong>Waypoint Desktop</strong>
          <span>релизы</span>
        </Link>
        <nav className="metric-nav-links">
          <Link to="/desktop/docs">Документация</Link>
          <Link to="/">Главная</Link>
        </nav>
      </header>

      <main className="metric-main">
        <p className="metric-pill">Канал {manifest?.channel ?? 'beta'}</p>
        <h1>Скачать Waypoint Desktop</h1>
        <p className="metric-lead">
          Актуальная версия: <strong>{manifest?.latest ?? '0.1.0'}</strong>
          {manifest?.updated ? ` · обновлено ${manifest.updated}` : null}
        </p>
        <div className="metric-actions">
          {downloadUrl ? (
            <a className="metric-btn metric-btn-primary" href={downloadUrl}>
              Скачать для Windows
            </a>
          ) : (
            <span className="metric-btn metric-btn-primary metric-btn-disabled">
              Сборка готовится — см. releases/waypoint-desktop
            </span>
          )}
          <Link className="metric-btn metric-btn-ghost" to="/desktop/docs/install">
            Инструкция по установке
          </Link>
        </div>

        <p className="metric-section-title">История версий</p>
        <div className="metric-release-list">
          {(manifest?.releases ?? []).map((r) => (
            <article key={r.version} className="metric-release-card">
              <h2>
                v{r.version} <span>{r.date}</span>
              </h2>
              <ul>
                {r.notes.map((n) => (
                  <li key={n}>{n}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>

        <p className="metric-section-title">Обновления</p>
        <p className="metric-lead">
          Новые версии публикуются на этой странице. Приложение сверяет номер версии при запуске.
        </p>
      </main>

      <footer className="metric-footer">
        © Waypoint Desktop · <a href={LINKS.metric}>Metric (облако)</a>
      </footer>
    </div>
  );
}
