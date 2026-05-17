import { Link } from 'react-router-dom';
import { WAYPOINT_METRIC_URL, WAYPOINT_CLUB_URL, ROZA_SITE_URL } from '../config/links';
import '../styles/lynx-google.css';

export function LizaPage() {
  return (
    <div className="google-page">
      <header className="google-header">
        <span className="google-logo">ЛИЗА</span>
        <Link to="/" style={{ color: '#1a73e8', fontSize: 14, textDecoration: 'none' }}>
          Lynx Hub
        </Link>
      </header>
      <main className="google-main">
        <h1>Помощник Waypoint</h1>
        <p>
          ЛИЗА встроена в Metric и Desktop: логи, ingest, документация, задачи разработчика. Отдельно — Roza AI для
          глубокой работы с кодом.
        </p>
        <div className="google-chips">
          <a className="google-chip" href={WAYPOINT_METRIC_URL} target="_blank" rel="noreferrer">
            Waypoint Metric
          </a>
          <a className="google-chip" href={WAYPOINT_CLUB_URL} target="_blank" rel="noreferrer">
            Waypoint Club
          </a>
          <a className="google-chip" href={`${ROZA_SITE_URL}/ai`} target="_blank" rel="noreferrer">
            Roza AI
          </a>
        </div>
        <article className="google-card">
          <h2>В консоли Metric</h2>
          <p>Анализ инцидентов и Ingest Lab после входа в workspace — зелёный бренд metrika-waypoint.ru.</p>
        </article>
        <article className="google-card">
          <h2>В Desktop</h2>
          <p>Отдельные нити диалога: календарь, качество кода, общий контекст приложения.</p>
        </article>
      </main>
    </div>
  );
}
