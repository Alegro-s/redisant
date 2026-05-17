import { Link } from 'react-router-dom';
import { RozaMark } from '../../components/roza/RozaMark';

export function RozaHubPage() {
  return (
    <main className="roza-main roza-hub-main">
      <section className="roza-hub-hero">
        <h1 className="roza-hub-title">Roza</h1>
        <p className="roza-hub-sub">Искусственный интеллект и платформа для разработки</p>
      </section>

      <div className="roza-hub-cards">
        <Link to="/roza/ai" className="roza-hub-card">
          <div className="roza-hub-card-head">
            <RozaMark variant="ai" size={44} />
            <div>
              <h2>Roza AI</h2>
              <p>Ассистент для кода и документов. Чат в духе Google и Apple.</p>
            </div>
          </div>
          <span className="roza-hub-link">Открыть →</span>
        </Link>
        <Link to="/roza/os" className="roza-hub-card">
          <div className="roza-hub-card-head">
            <RozaMark variant="os" size={44} />
            <div>
              <h2>Roza OS</h2>
              <p>Дистрибутив для разработки: один образ, понятная презентация.</p>
            </div>
          </div>
          <span className="roza-hub-link">Подробнее →</span>
        </Link>
      </div>
    </main>
  );
}
