import { Link } from 'react-router-dom';
import { ROZA_SECURITY_MSI_URL } from '../config/links';

const MSI =
  ROZA_SECURITY_MSI_URL ||
  'https://s3.twcstorage.ru/bc39a46d-ee3d-4707-9e3f-9529afb602da/roza-security-updates/msi/RozaSecurity-Setup.msi';

const features = [
  {
    title: 'Windows',
    body: 'Агент на рабочей станции: процессы, сеть и уведомления о подозрительной активности.',
  },
  {
    title: 'Roza OS',
    body: 'Linux-агент, systemd и «Защита Roza» в центре управления, связка с threat-guard.',
  },
  {
    title: 'Серия Roza',
    body: 'Roza AI для консультаций, Roza OS как среда, Security — защита рабочего места.',
  },
];

export function RozaSecurityPage() {
  return (
    <main className="roza-main roza-security-page">
      <section className="roza-security-hero">
        <p className="roza-hub-waypoint">Waypoint · Roza</p>
        <h1 className="roza-security-wordmark">
          Roza <span>Security</span>
        </h1>
        <p className="roza-security-lead">
          Защита Windows и мониторинг в Roza OS. Один контур безопасности в линейке Roza.
        </p>
        <div className="roza-security-actions">
          <a className="roza-security-btn roza-security-btn-primary" href={MSI} download>
            Скачать для Windows (.msi)
          </a>
          <Link className="roza-security-btn roza-security-btn-ghost" to="/os">
            Roza OS
          </Link>
          <Link className="roza-security-btn roza-security-btn-ghost" to="/os/docs">
            Документация ОС
          </Link>
        </div>
      </section>

      <section className="roza-security-grid" aria-labelledby="roza-sec-feat">
        <h2 id="roza-sec-feat" className="roza-hub-section-title roza-hub-section-title-left">
          Возможности
        </h2>
        <div className="roza-security-cards">
          {features.map((f) => (
            <article key={f.title} className="roza-security-card">
              <h3>{f.title}</h3>
              <p>{f.body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="roza-security-os-band">
        <h2>В Roza OS 0.6+</h2>
        <p>
          Агент <code>roza-sec-linux</code> и мост threat-guard уже в образе. Подробности — в документации
          дистрибутива.
        </p>
        <Link to="/os/docs" className="roza-security-inline">
          Документация Roza OS →
        </Link>
      </section>
    </main>
  );
}
