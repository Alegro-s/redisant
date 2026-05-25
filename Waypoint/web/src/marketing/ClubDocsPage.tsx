import { Link, useParams, Navigate } from 'react-router-dom';
import '../styles/club.css';
import '../styles/metric-public.css';
import { CLUB_DOCS, type ClubDocProduct } from './clubDocsContent';
import { usePageMeta } from '../hooks/usePageMeta';

const VALID = new Set<string>(Object.keys(CLUB_DOCS));

const NAV: { topic: ClubDocProduct; label: string }[] = [
  { topic: 'metric', label: 'Waypoint Metric' },
  { topic: 'desktop', label: 'Waypoint Desktop' },
  { topic: 'lynx', label: 'Lynx' },
  { topic: 'roza-ai', label: 'Roza AI' },
  { topic: 'roza-os', label: 'Roza OS' },
  { topic: 'tspu', label: 'ТГПУ Профиль' },
];

export function ClubDocsPage() {
  const { product } = useParams<{ product: string }>();
  if (!product || !VALID.has(product)) {
    return <Navigate to="/" replace />;
  }
  const key = product as ClubDocProduct;
  const doc = CLUB_DOCS[key];

  usePageMeta({
    title: `${doc.title} — Waypoint Club`,
    description: doc.subtitle,
    themeColor: '#06080d',
  });

  return (
    <div className="club-public metric-public metric-doc-layout club-doc-theme">
      <header className="metric-nav club-nav-doc">
        <Link to="/" className="metric-brand club-logo-doc">
          <strong>Waypoint Club</strong>
          <span>документация</span>
        </Link>
        <nav className="metric-nav-links">
          <Link to="/">Каталог</Link>
          <a href="/#products">Продукты</a>
        </nav>
      </header>

      <main className="metric-main metric-doc-main">
        <Link to="/#docs" className="metric-doc-back">
          ← Документация Club
        </Link>

        <div className="metric-doc-grid">
          <aside className="metric-doc-aside">
            <p className="metric-doc-aside-title">Продукты</p>
            <nav className="metric-doc-nav">
              {NAV.map((item) => (
                <Link
                  key={item.topic}
                  to={`/club/docs/${item.topic}`}
                  className={item.topic === key ? 'is-active' : undefined}
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
          </article>
        </div>
      </main>

      <footer className="metric-footer club-footer-doc">© Waypoint Club</footer>
    </div>
  );
}
