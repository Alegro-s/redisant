import { Link, useParams, Navigate } from 'react-router-dom';
import '../styles/club.css';
import { CLUB_DOCS, type ClubDocProduct } from './clubDocsContent';

const VALID = new Set<string>(Object.keys(CLUB_DOCS));

export function ClubDocsPage() {
  const { product } = useParams<{ product: string }>();
  if (!product || !VALID.has(product)) {
    return <Navigate to="/" replace />;
  }
  const doc = CLUB_DOCS[product as ClubDocProduct];

  return (
    <div className="club-root">
      <nav className="club-nav">
        <Link to="/" className="club-logo">
          Waypoint <em>Club</em>
        </Link>
        <div className="club-nav-links">
          <Link to="/">Каталог</Link>
          <a href="/#docs">Все документы</a>
        </div>
      </nav>

      <main className="club-main club-doc-page">
        <Link to="/#docs" className="club-doc-back">
          ← Документация Club
        </Link>
        <h1>{doc.title}</h1>
        <p className="club-doc-sub">{doc.subtitle}</p>
        {doc.sections.map((s) => (
          <section key={s.h} className="club-doc-section">
            <h2>{s.h}</h2>
            <p>{s.p}</p>
          </section>
        ))}
      </main>

      <footer className="club-footer">© Waypoint Club</footer>
    </div>
  );
}
