import { ROZA_ACCOUNT_URL, ROZA_COMPANION_WIN_URL } from '../../config/links';

const PILLARS = [
  {
    id: 'docs',
    title: 'Документы',
    text: 'Сводки, структура и ответы по вашим файлам. В приложении — вложения с диска.',
    icon: '📄',
  },
  {
    id: 'security',
    title: 'Безопасность ПК',
    text: 'Подсказки по подозрительной активности, процессам и настройкам системы.',
    icon: '🛡',
  },
  {
    id: 'learn',
    title: 'Обучение',
    text: 'Сценарии, журнал прогресса и студия знаний в десктопном консультанте.',
    icon: '✦',
  },
];

const REQUIREMENTS = [
  'Windows 10/11, 64-bit',
  'Среда .NET 8 (Desktop Runtime)',
  'Локальный сервер Roza (запускается с приложением)',
  '4 ГБ RAM, ~200 МБ на диске',
];

export function RozaAiFeatures() {
  const canDownload = Boolean(ROZA_COMPANION_WIN_URL);

  return (
    <section className="roza-ai-features" aria-labelledby="roza-features-title">
      <h2 id="roza-features-title" className="roza-ai-features-heading">
        Приложение для Windows
      </h2>
      <p className="roza-ai-features-lead">
        В браузере — быстрый чат. На ПК — полный консультант: документы, диагностика системы и обучение без отправки
        файлов в облако без вашего согласия.
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
          <h3>Требования</h3>
          <ul>
            {REQUIREMENTS.map((r) => (
              <li key={r}>{r}</li>
            ))}
          </ul>
        </div>
        <div className="roza-ai-requirements-actions">
          {canDownload ? (
            <a className="roza-download-btn" href={ROZA_COMPANION_WIN_URL} download>
              Скачать Roza для Windows
            </a>
          ) : (
            <p className="roza-download-unavail">Сборка появится после публикации.</p>
          )}
          <a className="roza-ai-panel-link" href={ROZA_ACCOUNT_URL}>
            Личный кабинет Roza
          </a>
        </div>
      </div>
    </section>
  );
}
