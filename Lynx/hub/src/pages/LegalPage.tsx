import { Link, useLocation } from 'react-router-dom';
import { lynxPrivacySections, lynxTermsSections } from '../content/lynxLegal';

export function LegalPage() {
  const { pathname } = useLocation();
  const isTerms = pathname.includes('/terms');
  const title = isTerms ? 'Условия использования' : 'Политика конфиденциальности';
  const sections = isTerms ? lynxTermsSections : lynxPrivacySections;

  return (
    <article className="lynx-legal-page">
      <p className="lynx-pill">Lynx Hub</p>
      <h1>{title}</h1>
      <p className="lynx-legal-lead">
        Документ относится к экосистеме Lynx (Launcher, Hub, Cloud). Другие бренды Waypoint — отдельные правила.
      </p>
      <nav className="lynx-legal-nav" aria-label="Юридические документы">
        <Link to="/privacy" className={!isTerms ? 'active' : undefined}>
          Конфиденциальность
        </Link>
        <Link to="/terms" className={isTerms ? 'active' : undefined}>
          Условия
        </Link>
      </nav>
      {sections.map((s) => (
        <section key={s.title} className="lynx-legal-section">
          <h2>{s.title}</h2>
          {s.paragraphs.map((p) => (
            <p key={p.slice(0, 40)}>{p}</p>
          ))}
        </section>
      ))}
      <p className="lynx-legal-foot">
        Текст носит информационный характер. Для коммерческого релиза согласуйте окончательную редакцию с юристом.
      </p>
      <p className="lynx-auth-back">
        <Link to="/">← На главную</Link>
      </p>
    </article>
  );
}
