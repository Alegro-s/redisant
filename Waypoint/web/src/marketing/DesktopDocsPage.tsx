import { useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import '../styles/metric-public.css';
import { LINKS } from './links';
import {
  DESKTOP_DOCS,
  DESKTOP_DOC_NAV,
  DESKTOP_COMPARE_ROWS,
  type DesktopDocTopic,
} from './desktopDocsContent';
import { searchDesktopDocs } from './desktopDocsIndex';
import { usePageMeta } from '../hooks/usePageMeta';

const VALID = new Set<string>(Object.keys(DESKTOP_DOCS));

const REQ_TABLE = [
  { os: 'Windows 10/11 x64', ram: '8 ГБ', disk: '4 ГБ', docker: 'Docker Desktop', status: 'Релиз' },
  { os: 'macOS 12+', ram: '8 ГБ', disk: '4 ГБ', docker: 'Docker Desktop', status: 'Beta' },
  { os: 'Ubuntu 22.04+', ram: '8 ГБ', disk: '4 ГБ', docker: 'Docker Engine', status: 'Beta' },
];

export function DesktopDocsPage() {
  const { topic } = useParams<{ topic?: string }>();
  const active: DesktopDocTopic =
    topic && VALID.has(topic) ? (topic as DesktopDocTopic) : 'start';
  const doc = DESKTOP_DOCS[active];
  const [q, setQ] = useState('');
  const hits = useMemo(() => searchDesktopDocs(q), [q]);

  usePageMeta({
    title: `${doc.title} — Waypoint Desktop`,
    description: doc.subtitle,
    themeColor: '#1a2744',
  });

  return (
    <div className="metric-public metric-doc-layout">
      <header className="metric-nav">
        <Link to="/" className="metric-brand">
          <strong>Waypoint Desktop</strong>
          <span>документация</span>
        </Link>
        <nav className="metric-nav-links">
          <Link to="/desktop/releases">Скачать</Link>
          <Link to="/">Главная</Link>
          <a href={LINKS.metric}>Metric</a>
        </nav>
      </header>

      <main className="metric-main metric-doc-main">
        <Link to="/" className="metric-doc-back">
          ← На главную Desktop
        </Link>

        <div className="metric-doc-search">
          <input
            type="search"
            placeholder="Поиск по документации…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            aria-label="Поиск"
          />
          {hits.length > 0 && (
            <ul className="metric-doc-search-hits">
              {hits.map((h, i) => (
                <li key={`${h.topic}-${h.section}-${i}`}>
                  <Link to={h.topic === 'start' ? '/desktop/docs' : `/desktop/docs/${h.topic}`}>
                    <strong>{h.label}</strong> — {h.section}
                    <span>{h.snippet}</span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="metric-doc-grid">
          <aside className="metric-doc-aside">
            <p className="metric-doc-aside-title">Разделы</p>
            <nav className="metric-doc-nav">
              {DESKTOP_DOC_NAV.map((item) => (
                <Link
                  key={item.topic}
                  to={item.topic === 'start' ? '/desktop/docs' : `/desktop/docs/${item.topic}`}
                  className={item.topic === active ? 'is-active' : undefined}
                >
                  {item.label}
                </Link>
              ))}
            </nav>
          </aside>

          <article className="metric-doc-article">
            <h1>{doc.title}</h1>
            <p className="metric-doc-sub">{doc.subtitle}</p>

            {active === 'requirements' && (
              <table className="metric-doc-table">
                <thead>
                  <tr>
                    <th>ОС</th>
                    <th>RAM</th>
                    <th>Диск</th>
                    <th>Docker</th>
                    <th>Статус</th>
                  </tr>
                </thead>
                <tbody>
                  {REQ_TABLE.map((r) => (
                    <tr key={r.os}>
                      <td>{r.os}</td>
                      <td>{r.ram}</td>
                      <td>{r.disk}</td>
                      <td>{r.docker}</td>
                      <td>{r.status}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {active === 'compare' && (
              <table className="metric-doc-table metric-doc-compare">
                <thead>
                  <tr>
                    <th>Возможность</th>
                    <th>Waypoint Desktop</th>
                    <th>Waypoint Metric</th>
                  </tr>
                </thead>
                <tbody>
                  {DESKTOP_COMPARE_ROWS.map((r) => (
                    <tr key={r.feature}>
                      <td>{r.feature}</td>
                      <td>{r.desktop}</td>
                      <td>{r.metric}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {doc.sections.map((s) => (
              <section key={s.h} className="metric-doc-section" id={s.h.replace(/\s+/g, '-')}>
                <h2>{s.h}</h2>
                <p>{s.p}</p>
              </section>
            ))}

            {active === 'cloud' && (
              <div className="metric-cta-band metric-doc-cta">
                <div>
                  <h2>Открыть облачный кабинет</h2>
                  <p>
                    Код привязки WD-XXXXXXXX создаётся в Metric → Настройки → Подключённые устройства.
                  </p>
                </div>
                <a className="metric-btn metric-btn-primary" href={LINKS.metric}>
                  Waypoint Metric →
                </a>
              </div>
            )}
          </article>
        </div>
      </main>

      <footer className="metric-footer">
        © Waypoint Desktop · <Link to="/desktop/releases">Скачать</Link> ·{' '}
        <Link to="/desktop/docs">Документация</Link>
      </footer>
    </div>
  );
}
