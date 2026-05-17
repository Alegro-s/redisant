import { Link } from 'react-router-dom';
import { RozaMark } from '../components/roza/RozaMark';
import { RozaChat } from '../components/roza/RozaChat';

const hubStarters = ['Сводка по документу', 'Что проверить на ПК?', 'План обучения'];

export function RozaHubPage() {
  return (
    <main className="roza-main roza-hub-main roza-hub-google">
      <section className="roza-hub-hero">
        <p className="roza-hub-waypoint">Waypoint · Roza</p>
        <h1 className="roza-hub-wordmark">Roza</h1>
        <p className="roza-hub-tagline">
          <span className="roza-hub-grad">Искусственный интеллект</span> для документов, безопасности ПК и обучения
        </p>
        <div className="roza-hub-chips" aria-label="Направления">
          <span className="roza-hub-chip">Документы</span>
          <span className="roza-hub-chip">Безопасность</span>
          <span className="roza-hub-chip">Обучение</span>
        </div>
      </section>

      <section className="roza-hub-chat-wrap">
        <RozaChat
          mini
          showChips={false}
          starters={hubStarters}
          placeholder="Спросите про документ, ПК или обучение…"
        />
      </section>

      <section className="roza-hub-products" aria-labelledby="roza-products-title">
        <h2 id="roza-products-title" className="roza-hub-section-title">
          Продукты
        </h2>
        <div className="roza-hub-product-grid">
          <Link to="/ai" className="roza-hub-product roza-hub-product-ai">
            <div className="roza-hub-product-visual">
              <RozaMark variant="ai" size={56} />
            </div>
            <div className="roza-hub-product-copy">
              <h3>Roza AI</h3>
              <p>Чат, API и приложение для Windows.</p>
              <span className="roza-hub-product-cta">Открыть Roza AI</span>
            </div>
          </Link>

          <Link to="/os" className="roza-hub-product roza-hub-product-os">
            <div className="roza-hub-product-visual">
              <RozaMark variant="os" size={56} />
            </div>
            <div className="roza-hub-product-copy">
              <h3>Roza OS</h3>
              <p>Операционная среда с встроенным ассистентом.</p>
              <span className="roza-hub-product-cta">Узнать о Roza OS</span>
            </div>
          </Link>
        </div>
      </section>
    </main>
  );
}
