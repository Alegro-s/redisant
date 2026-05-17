import { Link } from 'react-router-dom';
import { RozaMark } from '../components/roza/RozaMark';

const chapters = [
  {
    id: 'why',
    title: 'Зачем Roza OS',
    lead: 'Единая среда вместо десятка разрозненных инструментов.',
    body: 'Предсказуемые обновления, локальные репозитории и политика данных в контуре РФ — для команд, которым важен контроль над рабочим местом.',
    tone: 'a',
    ai: false,
  },
  {
    id: 'ai',
    title: 'ИИ внутри системы',
    lead: 'Ассистент понимает контекст рабочего стола.',
    body: 'Roza AI встроен в оболочку: подсказки в терминале, разбор логов, помощь с пакетами и настройкой IDE — без переключения в браузер.',
    tone: 'b',
    ai: true,
    chips: ['Контекст сессии', 'Терминал · IDE', 'Локально', 'Приватность'],
  },
  {
    id: 'inside',
    title: 'Что внутри',
    lead: 'Всё необходимое в одном образе.',
    body: 'Модульное ядро, терминал, IDE, менеджер пакетов и сетевой стек. Без лишних пакетов на старте.',
    tone: 'c',
    ai: false,
    chips: ['Ядро stable', 'Пакеты', 'Сеть', 'Обновления'],
  },
];

export function RozaOsPage() {
  return (
    <main className="roza-main roza-os-present">
      <section className="roza-os-cinema">
        <div className="roza-os-cinema-bg" aria-hidden />
        <div className="roza-os-cinema-inner">
          <p className="roza-hub-waypoint">Waypoint · Roza</p>
          <RozaMark variant="os" size={52} />
          <h1>Roza OS</h1>
          <p className="roza-os-cinema-tag">Дистрибутив с встроенным ИИ</p>
        </div>
      </section>

      {chapters.map((ch, i) => (
        <section
          key={ch.id}
          className={`roza-os-chapter ${i % 2 === 1 ? 'alt' : ''} ${ch.ai ? 'has-ai' : ''}`}
          id={ch.id}
        >
          <div className="roza-os-chapter-text">
            {ch.ai ? <span className="roza-os-ai-badge">Roza AI</span> : null}
            <h2>{ch.title}</h2>
            <p className="roza-os-chapter-lead">{ch.lead}</p>
            <p>{ch.body}</p>
            {ch.chips ? (
              <ul className="roza-os-chips">
                {ch.chips.map((c) => (
                  <li key={c}>{c}</li>
                ))}
              </ul>
            ) : null}
          </div>
          <div className={`roza-os-chapter-visual tone-${ch.tone}`} aria-hidden>
            {ch.ai ? (
              <>
                <div className="roza-os-ai-panel">
                  <span className="roza-os-ai-dot" />
                  <p>Спросите про конфиг ядра…</p>
                </div>
                <div className="roza-os-float-ui u1" />
                <div className="roza-os-float-ui u2 terminal" />
              </>
            ) : (
              <>
                <div className="roza-os-float-ui u1" />
                <div className="roza-os-float-ui u2" />
                <div className="roza-os-float-ui u3" />
              </>
            )}
          </div>
        </section>
      ))}

      <section className="roza-os-release-stage">
        <div className="roza-os-release-card">
          <RozaMark variant="os" size={36} />
          <h2>Roza OS 1.0 Alpha</h2>
          <p>x86_64 · ~2.1 GB · единственная версия на этапе пилота</p>
          <button type="button" disabled>
            Скачать ISO — скоро
          </button>
        </div>
      </section>

      <p className="roza-os-footer-links">
        <Link to="/ai">Roza AI</Link>
        <Link to="/">Обзор</Link>
      </p>
    </main>
  );
}
