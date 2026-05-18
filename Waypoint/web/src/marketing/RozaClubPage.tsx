import { useEffect } from 'react';
import { Link } from 'react-router-dom';
import '../styles/roza-marketing.css';
import { clubPath, rozaAppPath } from './links';

const ROZA_ICON = '/roza-icon.svg';

const apps = [
  {
    title: 'Roza AI',
    text: 'Чат-консультант Waypoint: документы, безопасность ПК и обучение.',
    href: rozaAppPath('ai'),
  },
  {
    title: 'Roza OS',
    text: 'Дистрибутив с ассистентом в системе — в линейке подсерии Roza.',
    href: rozaAppPath('os'),
  },
  {
    title: 'Кабинет',
    text: 'Подписка, ключи API и настройки аккаунта Roza.',
    href: rozaAppPath('account'),
  },
];

export function RozaClubPage() {
  useEffect(() => {
    document.body.classList.add('roza-body');
    document.title = 'Roza — подсерия Waypoint Club';
    return () => {
      document.body.classList.remove('roza-body');
    };
  }, []);

  return (
    <div className="roza-root">
      <header className="roza-nav">
        <Link to="/roza" className="roza-brand">
          <img src={ROZA_ICON} alt="" className="roza-brand-icon" width={36} height={36} />
          <span>
            Roza <em>подсерия Waypoint</em>
          </span>
        </Link>
        <nav>
          <a href="#apps">Приложения</a>
          <Link to={clubPath('/')}>Waypoint Club</Link>
        </nav>
      </header>

      <div className="roza-wrap">
        <section className="roza-hero" id="about">
          <p className="roza-eyebrow">Подсерия экосистемы</p>
          <h1>ИИ-ассистент и ОС в линейке Waypoint</h1>
          <p className="roza-lead">
            Roza — отдельная продуктовая линия на Waypoint Club: веб-чат, приложения и дистрибутив. Как ТГПУ
            Профиль, витрина живёт на клубном домене, а рабочие приложения — по путям <code>/roza/…</code>.
          </p>
          <div className="roza-btn-row">
            <a href={rozaAppPath('ai')} className="roza-btn roza-btn-primary">
              Открыть Roza AI
            </a>
            <a href={rozaAppPath()} className="roza-btn roza-btn-ghost">
              Приложение Roza
            </a>
          </div>
        </section>

        <section className="roza-tiles" id="apps">
          {apps.map(({ title, text, href }) => (
            <article key={title} className="roza-tile">
              <h3>{title}</h3>
              <p>{text}</p>
              <p style={{ marginTop: 16 }}>
                <a href={href}>Перейти →</a>
              </p>
            </article>
          ))}
        </section>
      </div>

      <footer className="roza-footer">
        <Link to={clubPath('/')}>Waypoint Club</Link>
        {' · '}
        <a href={rozaAppPath('ai')}>Roza AI</a>
        {' · '}
        <a href={rozaAppPath('account')}>Аккаунт</a>
      </footer>
    </div>
  );
}
