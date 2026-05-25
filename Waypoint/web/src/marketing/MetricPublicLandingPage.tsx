import { Link } from 'react-router-dom';
import '../styles/metric-public.css';
import { LINKS } from './links';
import { usePageMeta } from '../hooks/usePageMeta';

const modules = [
  {
    title: 'Облачная база',
    body: 'PostgreSQL, REST и ключи в кабинете — удобство как у Supabase, плюс ingest Waypoint.',
    to: '/register?plan=basic',
  },
  {
    title: 'Метрики и события',
    body: 'Сбор из приложений, ботов и сервисов — сводки и алерты в workspace.',
    to: '/register?plan=basic',
  },
  {
    title: 'Waypoint Desktop',
    body: 'Привязка программы на ПК к облаку: терминал и Docker рядом с Metric.',
    to: '/register?plan=basic',
  },
  {
    title: 'Ключи и API',
    body: 'Ключи ingest и BaaS выдаются после настройки workspace.',
    to: '/register?plan=basic',
  },
];

const docLinks = [
  { to: '/metric/docs', label: 'Начало', desc: 'Первые шаги и обзор продукта.' },
  { to: '/metric/docs/ingest', label: 'Ingest', desc: 'События, ключи и потоки данных.' },
  { to: '/metric/docs/baas', label: 'BaaS', desc: 'PostgreSQL, REST и файлы.' },
  { to: '/metric/docs/desktop', label: 'Desktop', desc: 'Связь с Waypoint Desktop.' },
];

export function MetricPublicLandingPage() {
  usePageMeta({
    title: 'Waypoint Metric — облачная консоль',
    description: 'Ingest, PostgreSQL, REST BaaS и дашборды в одном workspace Waypoint.',
    themeColor: '#070b12',
  });

  return (
    <div className="metric-public">
      <header className="metric-nav">
        <Link to="/" className="metric-brand">
          <strong>Waypoint Metric</strong>
          <span>облачная консоль</span>
        </Link>
        <nav className="metric-nav-links">
          <Link to="/metric/docs">Документация</Link>
          <a href="#modules">Модули</a>
          <a href="#docs">Разделы</a>
          <Link to="/register?plan=basic">Регистрация</Link>
          <a href={LINKS.club}>Club</a>
          <a href={LINKS.desktop}>Desktop</a>
        </nav>
      </header>

      <main className="metric-main">
        <section className="metric-hero">
          <p className="metric-pill">Облако · Waypoint</p>
          <h1>
            Метрики, <em>PostgreSQL</em> и BaaS в одном workspace
          </h1>
          <p className="metric-lead">
            <strong>Waypoint Metric</strong> — ingest, дашборды и облачная база для приложений. Локальный Docker и
            терминал — в{' '}
            <a href={LINKS.desktop} className="metric-inline-link">
              Waypoint Desktop
            </a>
            .
          </p>
          <div className="metric-actions">
            <Link className="metric-btn metric-btn-primary" to="/register?plan=basic">
              Создать workspace
            </Link>
            <Link className="metric-btn metric-btn-ghost" to="/metric/docs">
              Документация
            </Link>
            <a className="metric-btn metric-btn-ghost" href={LINKS.club}>
              Waypoint Club
            </a>
          </div>
        </section>

        <p className="metric-section-title" id="modules">
          Модули
        </p>
        <div className="metric-grid-3 metric-grid-3-wide">
          {modules.map((m) => (
            <Link key={m.title} to={m.to} className="metric-feature metric-feature-link">
              <h3>{m.title}</h3>
              <p>{m.body}</p>
            </Link>
          ))}
        </div>

        <div className="metric-db-block">
          <h3>База как у Supabase — плюс метрики Waypoint</h3>
          <p>
            Таблицы, REST, storage и ключи в кабинете. Ingest Lab и дашборды — в том же аккаунте, без отдельного
            сервера для старта.
          </p>
        </div>

        <p className="metric-section-title" id="docs">
          Документация
        </p>
        <div className="metric-grid-3 metric-grid-3-wide">
          {docLinks.map((d) => (
            <Link key={d.to} to={d.to} className="metric-feature metric-feature-link">
              <h3>{d.label}</h3>
              <p>{d.desc}</p>
            </Link>
          ))}
        </div>

        <section className="metric-cta-band">
          <div>
            <h2>Начните с бесплатного workspace</h2>
            <p>Регистрация, ingest и PostgreSQL — после входа в кабинет.</p>
          </div>
          <Link className="metric-btn metric-btn-primary" to="/register?plan=basic">
            Регистрация →
          </Link>
        </section>

        <footer className="metric-footer">
          © Waypoint Metric · <a href={LINKS.club}>Club</a> · <Link to="/metric/docs">Документация</Link>
        </footer>
      </main>
    </div>
  );
}
