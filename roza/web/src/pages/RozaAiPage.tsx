import { Link } from 'react-router-dom';
import { RozaMark } from '../components/roza/RozaMark';
import { RozaChat } from '../components/roza/RozaChat';
import { RozaAiFeatures } from '../components/roza/RozaAiFeatures';

const starters = ['Сводка по документу', 'Проверка безопасности ПК', 'С чего начать обучение?'];

export function RozaAiPage() {
  return (
    <main className="roza-main roza-ai-page roza-ai-google">
      <section className="roza-ai-hero-google">
        <p className="roza-hub-waypoint">Waypoint · Roza</p>
        <div className="roza-ai-hero-mark">
          <RozaMark variant="ai" size={52} />
        </div>
        <h1 className="roza-ai-wordmark">Roza AI</h1>
        <p className="roza-ai-tagline">
          <span className="roza-hub-grad">Документы</span>, безопасность ПК и обучение
        </p>
      </section>

      <section className="roza-ai-chat-wrap">
        <RozaChat starters={starters} placeholder="Спросите Roza…" />
      </section>

      <RozaAiFeatures />

      <p className="roza-ai-footer-links">
        <Link to="/account">Личный кабинет</Link>
        <Link to="/os">Roza OS</Link>
        <Link to="/">На главную</Link>
        <Link to="/os">Roza OS</Link>
        <Link to="/">На главную</Link>
        <Link to="/os">Roza OS</Link>
        <Link to="/">На главную</Link>
      </p>
    </main>
  );
}
