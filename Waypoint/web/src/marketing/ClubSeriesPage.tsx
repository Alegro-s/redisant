import { Link } from 'react-router-dom';
import '../styles/club.css';
import { LINKS, rozaPath, rozaAppPath } from './links';
import { resolvePublicSiteMode } from './siteMode';
import { usePageMeta } from '../hooks/usePageMeta';

export function ClubSeriesPage() {
  const onClub = resolvePublicSiteMode() === 'club';
  const homeHref = onClub ? '/' : LINKS.club;

  usePageMeta({
    title: 'Серия Waypoint и подсерия Roza — Waypoint Club',
    description: 'Продуктовая линейка: Metric, Desktop, Lynx, Roza, кампусные решения.',
    themeColor: '#0d0d12',
  });

  return (
    <div className="club-root">
      <nav className="club-nav">
        {onClub ? (
          <Link to="/" className="club-logo">
            Waypoint <em>Club</em>
          </Link>
        ) : (
          <a href={LINKS.club} className="club-logo">
            Waypoint <em>Club</em>
          </a>
        )}
        <div className="club-nav-links">
          {onClub ? <Link to="/">Каталог</Link> : <a href={LINKS.club}>Каталог</a>}
          <a href={onClub ? '/#docs' : `${LINKS.club}/#docs`}>Документация</a>
        </div>
      </nav>
      <main className="club-main club-doc-page">
        {onClub ? (
          <Link to={homeHref} className="club-doc-back">
            ← На главную Club
          </Link>
        ) : (
          <a href={homeHref} className="club-doc-back">
            ← На главную Club
          </a>
        )}
        <h1>Серия Waypoint</h1>
        <p className="club-doc-sub">
          Единая линейка для разработки, облака и эксплуатации. У каждого продукта свой сайт и контур данных.
        </p>
        <section className="club-doc-section">
          <h2>Waypoint Metric</h2>
          <p>Облако: ingest, PostgreSQL, BaaS, команда. Сайт: {LINKS.metric}</p>
        </section>
        <section className="club-doc-section">
          <h2>Waypoint Desktop</h2>
          <p>
            Локальное приложение на ПК — раздел на домене Metric:{' '}
            <a href={LINKS.desktop} target="_blank" rel="noreferrer">
              {LINKS.desktop}
            </a>
          </p>
        </section>
        <section className="club-doc-section">
          <h2>Подсерия Roza</h2>
          <p>
            Roza AI и Roza OS — ассистент и дистрибутив внутри экосистемы Waypoint.{' '}
            <Link to={rozaPath()}>Roza</Link>
            {' · '}
            <a href={rozaAppPath('ai')}>Roza AI</a>
            {' · '}
            <a href={rozaAppPath('os')}>Roza OS</a>
          </p>
        </section>
        <section className="club-doc-section">
          <h2>Lynx</h2>
          <p>
            Игровой движок: Lynx Hub (launcher) и Lynx Cloud (кабинет автора). Отдельные домены, не смешиваются с Metric.
          </p>
        </section>
      </main>
      <footer className="club-footer">© Waypoint Club</footer>
    </div>
  );
}
