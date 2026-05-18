import { Link } from 'react-router-dom';
import '../styles/metric-public.css';
import { LINKS, desktopHome } from './desktopNav';
import { usePageMeta } from '../hooks/usePageMeta';

const steps = [
  { n: '1', label: 'Скачать', sub: 'Установщик для Windows' },
  { n: '2', label: 'Настроить', sub: 'Docker и рабочая папка' },
  { n: '3', label: 'Работать', sub: 'Терминал и Liza локально' },
  { n: '4', label: 'Синхрон', sub: 'Опционально с облаком Metric' },
];

const features = [
  {
    title: 'Контейнеры',
    body: 'Запуск и управление Docker-проектами на своей машине — без обязательного облачного ingest.',
  },
  {
    title: 'Терминал',
    body: 'Встроенная оболочка, скрипты и планировщик задач рядом с вашим кодом.',
  },
  {
    title: 'Liza на ПК',
    body: 'Локальный ассистент для окружения и кода — отдельно от облачной Liza в Metric.',
  },
  {
    title: 'Офлайн-режим',
    body: 'Критичные сценарии разработки доступны без постоянной связи с сервером.',
  },
  {
    title: 'Чёткое разделение',
    body: 'Desktop не подменяет PostgreSQL, BaaS и ingest — они остаются в Waypoint Metric.',
  },
  {
    title: 'Экосистема',
    body: 'Club, Lynx Hub и Lynx Cloud — отдельные продукты со своими сайтами и кабинетами.',
  },
];

/** Витрина Waypoint Desktop — синяя айдентика (отдельный домен / порт). */
export function DesktopLandingPage() {
  usePageMeta({
    title: 'Waypoint Desktop — приложение для ПК',
    description:
      'Локальный клиент Waypoint: Docker, терминал, Liza. Опциональная связь с облаком Waypoint Metric.',
    themeColor: '#1a2744',
  });

  return (
    <div className="metric-public">
      <header className="metric-nav">
        <Link to={desktopHome} className="metric-brand">
          <strong>Waypoint Desktop</strong>
          <span>локальное приложение · не облако</span>
        </Link>
        <nav className="metric-nav-links">
          <Link to="/desktop/docs">Документация</Link>
          <Link to="/desktop/releases">Скачать</Link>
          <a href="#workflow">Как начать</a>
          <a href="#features">Возможности</a>
          <a href={LINKS.metric}>Metric (облако)</a>
          <a href={LINKS.club}>Club</a>
        </nav>
      </header>

      <main className="metric-main">
        <section className="metric-hero" id="about">
          <p className="metric-pill">Сайт продукта · ПК</p>
          <h1>
            Рабочее место разработчика на <em>вашем компьютере</em>
          </h1>
          <p className="metric-lead">
            <strong>Waypoint Desktop</strong> — локальный клиент: Docker, терминал и Liza. Для облачных метрик, PostgreSQL
            и BaaS используйте отдельный продукт{' '}
            <a href={LINKS.metric} className="metric-inline-link">
              Waypoint Metric
            </a>
            .
          </p>
          <div className="metric-actions">
            <a className="metric-btn metric-btn-primary" href={LINKS.desktopDownload}>
              Скачать для Windows
            </a>
            <a className="metric-btn metric-btn-ghost" href={LINKS.metric}>
              Облако Metric →
            </a>
            <Link className="metric-btn metric-btn-ghost" to="/desktop/docs">
              Документация
            </Link>
            <Link className="metric-btn metric-btn-ghost" to="/desktop/docs/cloud">
              Связь с облаком
            </Link>
          </div>
        </section>

        <p className="metric-section-title" id="workflow">
          Как начать
        </p>
        <div className="metric-steps">
          {steps.map((s) => (
            <article key={s.n} className="metric-step-card">
              <span className="metric-step-num">Шаг {s.n}</span>
              <strong>{s.label}</strong>
              <span>{s.sub}</span>
            </article>
          ))}
        </div>

        <p className="metric-section-title">Metric и Desktop</p>
        <div className="metric-split">
          <article className="metric-product-card">
            <h2>Waypoint Metric</h2>
            <p className="metric-tag">Облако</p>
            <ul>
              <li>Ingest Lab, дашборды, алерты</li>
              <li>PostgreSQL и REST BaaS</li>
              <li>Команда, API-ключи, storage</li>
            </ul>
            <a className="metric-link" href={LINKS.metric}>
              Сайт облака →
            </a>
          </article>
          <article className="metric-product-card is-you">
            <h2>Waypoint Desktop</h2>
            <p className="metric-tag">Вы здесь · ПК</p>
            <ul>
              <li>Docker и терминал локально</li>
              <li>Liza на рабочем столе</li>
              <li>Не заменяет облачный ingest</li>
            </ul>
            <a className="metric-link" href="#features">
              Возможности →
            </a>
          </article>
        </div>

        <p className="metric-section-title" id="features">
          Возможности Desktop
        </p>
        <div className="metric-grid-3 metric-grid-3-wide">
          {features.map((f) => (
            <article key={f.title} className="metric-feature">
              <h3>{f.title}</h3>
              <p>{f.body}</p>
            </article>
          ))}
        </div>

        <p className="metric-section-title" id="docs">
          Документация на этом сайте
        </p>
        <div className="metric-grid-3 metric-grid-3-wide">
          <Link to="/desktop/docs/install" className="metric-feature metric-feature-link">
            <h3>Установка</h3>
            <p>Требования, первый запуск и настройка Docker.</p>
          </Link>
          <Link to="/desktop/docs/cloud" className="metric-feature metric-feature-link">
            <h3>Связь с облаком</h3>
            <p>Один аккаунт, API-ключ workspace и ingest с ПК.</p>
          </Link>
          <Link to="/desktop/docs/faq" className="metric-feature metric-feature-link">
            <h3>FAQ</h3>
            <p>Ответы на частые вопросы по Desktop и Metric.</p>
          </Link>
        </div>

        <section className="metric-cta-band">
          <div>
            <h2>Нужны метрики и база в облаке?</h2>
            <p>Waypoint Metric — ingest, PostgreSQL и BaaS после регистрации workspace.</p>
          </div>
          <a className="metric-btn metric-btn-primary" href={LINKS.metric}>
            Перейти на Metric →
          </a>
        </section>

        <footer className="metric-footer">
          © Waypoint Desktop · часть экосистемы{' '}
          <a href={LINKS.club}>Waypoint Club</a>. Облако:{' '}
          <a href={LINKS.metric}>{LINKS.metric.replace(/^https?:\/\//, '')}</a>
        </footer>
      </main>
    </div>
  );
}
