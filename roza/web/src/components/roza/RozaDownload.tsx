import { ROZA_COMPANION_WIN_URL } from '../../config/links';

const FEATURES = [
  { title: 'Документы', text: 'Сводки, разбор и работа с файлами на вашем ПК.' },
  { title: 'Безопасность', text: 'Анализ системы и подозрительной активности.' },
  { title: 'Обучение', text: 'Сценарии, журнал прогресса и студия знаний.' },
];

export function RozaDownload({ compact = false }: { compact?: boolean }) {
  const ready = Boolean(ROZA_COMPANION_WIN_URL);

  return (
    <section className={`roza-download${compact ? ' roza-download-compact' : ''}`} aria-labelledby="roza-dl-title">
      <h2 id="roza-dl-title" className="roza-download-title">
        Приложение Roza для Windows
      </h2>
      {!compact ? (
        <p className="roza-download-lead">
          Десктоп-консультант для документов, диагностики ПК и обучения. Требуется .NET 8 и локальный сервер Roza (запускается
          вместе с приложением).
        </p>
      ) : null}
      <ul className="roza-download-features">
        {FEATURES.map((f) => (
          <li key={f.title}>
            <strong>{f.title}</strong>
            <span>{f.text}</span>
          </li>
        ))}
      </ul>
      {ready ? (
        <a className="roza-download-btn" href={ROZA_COMPANION_WIN_URL} download>
          Скачать для Windows
        </a>
      ) : (
        <p className="roza-download-unavail">Сборка появится после публикации релиза.</p>
      )}
    </section>
  );
}
