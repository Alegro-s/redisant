import { useState } from 'react';
import { Link } from 'react-router-dom';
import { RozaMark } from '../../components/roza/RozaMark';

const starters = [
  'Сводка по модулю ingest',
  'План рефакторинга API',
  'Структура отчёта для ректората',
];

const seedMessages = [
  { role: 'user' as const, text: 'Как подключить ЛИЗА к нашему сервису?' },
  {
    role: 'liza' as const,
    text: 'Оформите подписку в личном кабинете Lynx Cloud — после оплаты откроется раздел API. Создайте ключ и вызывайте POST /v1/liza/chat из своего приложения.',
  },
];

export function RozaAiPage() {
  const [prompt, setPrompt] = useState('');
  const [messages, setMessages] = useState<{ role: 'user' | 'liza'; text: string }[]>(seedMessages);
  const [pending, setPending] = useState(false);

  function send(text?: string) {
    const q = (text ?? prompt).trim();
    if (!q || pending) return;
    setPrompt('');
    setMessages((m) => [...m, { role: 'user', text: q }]);
    setPending(true);
    window.setTimeout(() => {
      setMessages((m) => [
        ...m,
        {
          role: 'liza',
          text:
            q.toLowerCase().includes('код') || q.toLowerCase().includes('рефактор')
              ? 'Roza AI для написания и разбора кода доступен только по заявке. В чате сейчас работает ЛИЗА через API после подписки в кабинете.'
              : 'ЛИЗА отвечает через API в личном кабинете (после оплаты подписки). Roza AI для кода — по отдельной заявке.',
        },
      ]);
      setPending(false);
    }, 750);
  }

  return (
    <main className="roza-main roza-ai-page">
      <header className="roza-ai-top">
        <div className="roza-ai-brand-row">
          <RozaMark variant="ai" size={40} />
          <div>
            <h1>Roza AI</h1>
            <p>Чат и API в стиле Google · Apple</p>
          </div>
        </div>
      </header>

      <section className="roza-ai-split">
        <article className="roza-ai-panel liza-panel">
          <h2>ЛИЗА в чате</h2>
          <p>
            Подключение через <strong>личный кабинет</strong> после оплаты подписки Lynx Cloud. Ключ API, лимиты и
            история — в консоли.
          </p>
          <ol className="roza-ai-steps-mini">
            <li>Регистрация и подписка</li>
            <li>Раздел «API» → ключ ЛИЗА</li>
            <li>POST /v1/liza/chat</li>
          </ol>
        </article>
        <article className="roza-ai-panel roza-panel">
          <h2>Roza AI для кода</h2>
          <p>
            Разбор репозиториев, генерация и рефакторинг — <strong>только по заявке</strong>. После одобрения выдаём
            отдельный ключ и документацию.
          </p>
          <button type="button" className="roza-ai-request-btn" disabled title="Форма заявки скоро">
            Запросить доступ
          </button>
        </article>
      </section>

      <section className="roza-chat-shell" aria-label="Чат">
        <div className="roza-chat-messages">
          {messages.map((msg, i) => (
            <div key={i} className={`roza-chat-row ${msg.role}`}>
              <div className="roza-chat-avatar">{msg.role === 'user' ? 'Вы' : 'ЛИЗА'}</div>
              <div className="roza-chat-bubble">{msg.text}</div>
            </div>
          ))}
          {pending ? (
            <div className="roza-chat-row liza">
              <div className="roza-chat-avatar">…</div>
              <div className="roza-chat-bubble roza-chat-typing">
                <span />
                <span />
                <span />
              </div>
            </div>
          ) : null}
        </div>
        <div className="roza-chat-composer">
          <div className="roza-chat-chips">
            {starters.map((s) => (
              <button key={s} type="button" className="roza-chip" onClick={() => send(s)}>
                {s}
              </button>
            ))}
          </div>
          <div className="roza-chat-input-wrap">
            <textarea
              value={prompt}
              onChange={(e) => setPrompt(e.target.value)}
              placeholder="Сообщение для ЛИЗА…"
              rows={1}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault();
                  send();
                }
              }}
            />
            <button type="button" className="roza-chat-send" onClick={() => send()} disabled={pending || !prompt.trim()}>
              ↑
            </button>
          </div>
        </div>
      </section>

      <p className="roza-ai-footer-links">
        <Link to="/roza/os">Roza OS</Link>
        <Link to="/roza">Обзор Roza</Link>
      </p>
    </main>
  );
}
