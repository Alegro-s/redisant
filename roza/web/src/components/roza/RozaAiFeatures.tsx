import { ROZA_ACCOUNT_URL } from '../../config/links';
import { Link } from 'react-router-dom';

const PILLARS = [
  {
    id: 'docs',
    title: 'Документы',
    text: 'Сводки, структура и ответы по вашим файлам.',
    icon: '📄',
  },
  {
    id: 'security',
    title: 'Безопасность',
    text: 'Подсказки по ПК и отдельный продукт Roza Security для Windows и Roza OS.',
    icon: '🛡',
  },
  {
    id: 'learn',
    title: 'Обучение',
    text: 'Сценарии и журнал прогресса в личном кабинете.',
    icon: '✦',
  },
];

export function RozaAiFeatures() {
  return (
    <section className="roza-ai-features" aria-labelledby="roza-features-title">
      <h2 id="roza-features-title" className="roza-ai-features-heading">
        Возможности Roza AI
      </h2>
      <p className="roza-ai-features-lead">
        В браузере — чат и консультации. Защита рабочего места — в{' '}
        <Link to="/security">Roza Security</Link>, среда с Liza — в <Link to="/os">Roza OS</Link>.
      </p>

      <div className="roza-ai-pillar-grid">
        {PILLARS.map((p) => (
          <article key={p.id} className="roza-ai-pillar">
            <span className="roza-ai-pillar-icon" aria-hidden>
              {p.icon}
            </span>
            <h3>{p.title}</h3>
            <p>{p.text}</p>
          </article>
        ))}
      </div>

      <div className="roza-ai-requirements-card">
        <div className="roza-ai-requirements-copy">
          <h3>Личный кабинет</h3>
          <p>Регистрация, настройки и история — в контуре Roza на Waypoint.</p>
        </div>
        <div className="roza-ai-requirements-actions">
          <Link className="roza-ai-panel-link roza-ai-panel-link-primary" to={ROZA_ACCOUNT_URL}>
            Открыть кабинет Roza
          </Link>
        </div>
      </div>
    </section>
  );
}
