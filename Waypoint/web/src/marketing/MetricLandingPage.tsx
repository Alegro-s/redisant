import { Link } from 'react-router-dom';
import '../styles/metric-public.css';
import { LINKS } from './links';
import { useDocumentTitle } from '../hooks/useDocumentTitle';

export function MetricLandingPage() {
  useDocumentTitle('Waypoint Metric — облачная консоль');
  return (
    <div className="metric-public">
      <header className="metric-nav">
        <Link to="/" className="metric-brand">
          <strong>Waypoint Metric</strong>
          <span>облачная консоль · не Desktop</span>
        </Link>
        <nav className="metric-nav-links">
          <a href={LINKS.club}>Club</a>
          <Link to="/login">Войти</Link>
          <Link to="/register">Регистрация</Link>
        </nav>
      </header>

      <main className="metric-main">
        <section className="metric-hero">
          <p className="metric-pill">Сайт продукта Metric</p>
          <h1>
            Метрики, <em>PostgreSQL</em> и backend в облаке
          </h1>
          <p className="metric-lead">
            Вы на витрине <strong>Waypoint Metric</strong> — веб-консоль после входа. Ingest, дашборды, BaaS и база
            данных для приложений. Это не Lynx и не игровой движок.
          </p>
          <div className="metric-actions">
            <Link className="metric-btn metric-btn-primary" to="/register">
              Создать workspace
            </Link>
            <Link className="metric-btn metric-btn-ghost" to="/login">
              Войти в консоль
            </Link>
            <a className="metric-btn metric-btn-ghost" href={`${LINKS.club}/club/docs/metric`}>
              Документация на Club
            </a>
          </div>
        </section>

        <p className="metric-section-title">Два разных продукта Waypoint</p>
        <div className="metric-split">
          <article className="metric-product-card is-you">
            <h2>Waypoint Metric</h2>
            <p className="metric-tag">Вы здесь · облако</p>
            <ul>
              <li>Ingest Lab, метрики, логи, алерты</li>
              <li>PostgreSQL и REST BaaS в кабинете</li>
              <li>Object storage, ключи API, команда</li>
              <li>Liza — ассистент внутри консоли</li>
            </ul>
            <Link className="metric-link" to="/register">
              Открыть workspace →
            </Link>
          </article>
          <article className="metric-product-card">
            <h2>Waypoint Desktop</h2>
            <p className="metric-tag">Отдельное приложение · ПК</p>
            <ul>
              <li>Docker, терминал, планировщик локально</li>
              <li>Не подменяет облачный ingest Metric</li>
              <li>Своя установка и философия работы</li>
              <li>Документация — на Club, не здесь</li>
            </ul>
            <a className="metric-link" href={`${LINKS.club}/club/docs/desktop`}>
              Документация Desktop →
            </a>
          </article>
        </div>

        <p className="metric-section-title">Возможности в консоли</p>
        <div className="metric-grid-3">
          <article className="metric-feature">
            <h3>Ingest и метрики</h3>
            <p>Потоки данных, Ingest Lab, дашборды — кто грузит сервер и почему.</p>
          </article>
          <article className="metric-feature">
            <h3>База данных</h3>
            <p>PostgreSQL в workspace: SQL, миграции, REST — backend под ваши приложения.</p>
          </article>
          <article className="metric-feature">
            <h3>BaaS и хранилище</h3>
            <p>REST API, файлы, AI-контур — после настройки workspace в кабинете.</p>
          </article>
        </div>

        <div className="metric-db-block">
          <h3>База данных в Metric</h3>
          <p>
            У каждого workspace — свой контур PostgreSQL и API. Управление схемой, ключами и лимитами — в разделах BaaS
            после входа. Отдельная БД у Roza AI и у Lynx Cloud — у других продуктов экосистемы.
          </p>
        </div>

        <p className="metric-section-title">Тарифы</p>
        <div className="metric-pricing">
          <article className="metric-feature">
            <h3>Basic</h3>
            <p>Старт: ingest, дашборды, лимиты по объёму.</p>
            <Link className="metric-link" to="/register?plan=basic">
              Начать →
            </Link>
          </article>
          <article className="metric-feature">
            <h3>Business / Enterprise</h3>
            <p>Расширенные лимиты, on-prem, договор в РФ.</p>
            <Link className="metric-link" to="/register?plan=business">
              Запросить →
            </Link>
          </article>
        </div>

        <footer className="metric-footer">
          © Waypoint Metric · облачная консоль. Waypoint Desktop и игровой Lynx — другие продукты на{' '}
          <a href={LINKS.club} style={{ color: 'var(--mp-accent-soft)' }}>
            Waypoint Club
          </a>
          .
        </footer>
      </main>
    </div>
  );
}
