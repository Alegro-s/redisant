import { Link, useParams } from 'react-router-dom';
import '../styles/metric-public.css';
import { LINKS, desktopDocsUrl } from './links';
import { METRIC_DOCS, METRIC_DOC_NAV, type MetricDocTopic } from './metricDocsContent';
import { usePageMeta } from '../hooks/usePageMeta';

const VALID = new Set<string>(Object.keys(METRIC_DOCS));

export function MetricDocsPage() {
  const { topic } = useParams<{ topic?: string }>();
  const active: MetricDocTopic =
    topic && VALID.has(topic) ? (topic as MetricDocTopic) : 'start';
  const doc = METRIC_DOCS[active];

  usePageMeta({
    title: `${doc.title} — Waypoint Metric`,
    description: doc.subtitle,
    themeColor: '#070b12',
  });

  return (
    <div className="metric-public metric-doc-layout">
      <header className="metric-nav">
        <Link to="/" className="metric-brand">
          <strong>Waypoint Metric</strong>
          <span>документация</span>
        </Link>
        <nav className="metric-nav-links">
          <Link to="/register?plan=basic">Регистрация</Link>
          <Link to="/">Главная</Link>
          <a href={LINKS.club}>Club</a>
        </nav>
      </header>

      <main className="metric-main metric-doc-main">
        <Link to="/" className="metric-doc-back">
          ← На главную Metric
        </Link>

        <div className="metric-doc-grid">
          <aside className="metric-doc-aside">
            <p className="metric-doc-aside-title">Разделы</p>
            <nav className="metric-doc-nav">
              {METRIC_DOC_NAV.map((item) => (
                <Link
                  key={item.topic}
                  to={item.topic === 'start' ? '/metric/docs' : `/metric/docs/${item.topic}`}
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
            {doc.sections.map((s) => (
              <section key={s.h} className="metric-doc-section">
                <h2>{s.h}</h2>
                <p>{s.p}</p>
              </section>
            ))}
            {active === 'desktop' && (
              <p className="metric-doc-section">
                <a href={desktopDocsUrl('cloud')} className="metric-inline-link">
                  Подробнее на сайте Desktop →
                </a>
              </p>
            )}
          </article>
        </div>
      </main>

      <footer className="metric-footer">
        © Waypoint Metric · <Link to="/">Главная</Link> · <a href={LINKS.club}>Club</a>
      </footer>
    </div>
  );
}
