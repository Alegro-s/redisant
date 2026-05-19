import { useEffect } from 'react';
import { Link } from 'react-router-dom';
import '../styles/tspu-marketing.css';
import { LINKS } from './links';
import { TspuAppMark, TspuFeatureIcon, type TspuFeatureIcon as FeatureId } from './TspuIcons';

const tiles: { id: FeatureId; title: string; text: string }[] = [
  { id: 'schedule', title: 'Расписание', text: 'Пары, преподаватели и аудитории — всегда под рукой.' },
  { id: 'grades', title: 'Успеваемость', text: 'Оценки и средний балл из учётных систем.' },
  { id: 'portfolio', title: 'Портфолио', text: 'Достижения и практика в одном разделе.' },
  { id: 'moodle', title: 'Moodle', text: 'Задания и материалы с портала вуза.' },
  { id: 'campus', title: 'Кампус', text: 'События и сервисы ТГПУ.' },
  { id: 'max', title: 'MAX', text: 'Веб-сборка для Mini App.' },
];

function TspuSyncGraph() {
  return (
    <div className="tspu-graph" aria-label="Схема синхронизации данных">
      <svg className="tspu-graph-lines" viewBox="0 0 720 320" aria-hidden>
        <defs>
          <linearGradient id="tspu-line-grad" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stopColor="#c45d45" stopOpacity="0.15" />
            <stop offset="45%" stopColor="#c45d45" />
            <stop offset="55%" stopColor="#e07a5f" />
            <stop offset="100%" stopColor="#c45d45" stopOpacity="0.15" />
          </linearGradient>
        </defs>
        <path id="tspu-p1" d="M120 72 C200 72 280 120 360 148" fill="none" stroke="url(#tspu-line-grad)" strokeWidth="2.5" className="tspu-graph-path" />
        <path id="tspu-p2" d="M600 72 C520 72 440 120 360 148" fill="none" stroke="url(#tspu-line-grad)" strokeWidth="2.5" className="tspu-graph-path delay" />
        <path id="tspu-p3" d="M360 192 L360 248" fill="none" stroke="url(#tspu-line-grad)" strokeWidth="2.5" className="tspu-graph-path delay2" />
        <circle r="4" fill="#c45d45" className="tspu-graph-dot">
          <animateMotion dur="2.8s" repeatCount="indefinite" path="M120 72 C200 72 280 120 360 148" />
        </circle>
        <circle r="4" fill="#c45d45" className="tspu-graph-dot">
          <animateMotion dur="2.8s" begin="0.4s" repeatCount="indefinite" path="M600 72 C520 72 440 120 360 148" />
        </circle>
        <circle r="4" fill="#c45d45" className="tspu-graph-dot">
          <animateMotion dur="1.6s" begin="1s" repeatCount="indefinite" path="M360 192 L360 248" />
        </circle>
      </svg>

      <article className="tspu-graph-node n-1c">
        <span className="tspu-graph-tag">1С</span>
        <strong>Учёт вуза</strong>
        <p>Расписание · оценки · справки</p>
      </article>
      <article className="tspu-graph-node n-moodle">
        <span className="tspu-graph-tag">Moodle</span>
        <strong>Портал обучения</strong>
        <p>Задания · материалы · сроки</p>
      </article>
      <article className="tspu-graph-node n-hub">
        <TspuAppMark size={40} />
        <strong>ТГПУ Профиль</strong>
        <p>Синхронизация · профиль · офлайн</p>
      </article>
      <article className="tspu-graph-node n-student">
        <strong>Студент</strong>
        <p>Персональный экран: витрина, пары, оценки, карта</p>
      </article>
    </div>
  );
}

export function TspuProductPage() {
  useEffect(() => {
    document.body.classList.add('tspu-body');
    return () => document.body.classList.remove('tspu-body');
  }, []);

  return (
    <div className="tspu-root">
      <header className="tspu-nav">
        <Link to="/tspu" className="tspu-brand">
          <TspuAppMark className="tspu-brand-icon" size={36} />
          <span>
            ТГПУ <em>профиль</em>
          </span>
        </Link>
        <nav>
          <a href="#app">Приложение</a>
          <a href="#sync">Данные</a>
          <a href={LINKS.university} target="_blank" rel="noreferrer">
            tsput.ru
          </a>
        </nav>
      </header>

      <div className="tspu-wrap">
        <section className="tspu-hero" id="app">
          <div className="tspu-hero-text">
            <p className="tspu-eyebrow">Мобильное приложение</p>
            <h1>Кабинет студента в телефоне</h1>
            <p className="tspu-lead">
              Индивидуальный опыт для обучающихся{' '}
              <a href={LINKS.university} target="_blank" rel="noreferrer">
                ТГПУ им. Л.Н. Толстого
              </a>
              : витрина сервисов, расписание, оценки и карта лояльности.
            </p>
            <div className="tspu-btn-row">
              <span className="tspu-btn tspu-btn-primary">Скоро в RuStore</span>
            </div>
          </div>

          <div className="tspu-hero-icon-showcase">
            <TspuAppMark className="tspu-hero-app-icon" size={280} />
          </div>
        </section>

        <section className="tspu-sync-section" id="sync">
          <h2>Как данные попадают в приложение</h2>
          <p className="tspu-sync-lead">
            Данные из систем вуза автоматически собираются в одном приложении — расписание, оценки и сервисы на одном
            экране, без лишних шагов.
          </p>
          <TspuSyncGraph />
        </section>

        <div className="tspu-services">
          {tiles.map(({ id, title, text }) => (
            <article key={title} className="tspu-tile">
              <span className="tspu-tile-icon" aria-hidden>
                <TspuFeatureIcon id={id} />
              </span>
              <h3>{title}</h3>
              <p>{text}</p>
            </article>
          ))}
        </div>
      </div>

      <footer className="tspu-footer">
        <a href={LINKS.university} target="_blank" rel="noreferrer">
          tsput.ru
        </a>
        {' · '}
        300026, г. Тула, пр-т Ленина, 125
      </footer>
    </div>
  );
}
