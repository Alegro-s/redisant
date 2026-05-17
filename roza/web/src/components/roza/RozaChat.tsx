import { useEffect, useRef, useState } from 'react';
import { RozaMark } from './RozaMark';
import { rozaChat } from '../../lib/rozaApi';
import { rozaDemoReply, rozaTypingDelayMs } from '../../lib/rozaDemoChat';

export type RozaChatMessage = { role: 'user' | 'assistant'; text: string };

type Props = {
  mini?: boolean;
  gemini?: boolean;
  starters?: string[];
  initialMessages?: RozaChatMessage[];
  placeholder?: string;
  showChips?: boolean;
};

const DEFAULT_STARTERS = ['Сводка по документу', 'Проверка безопасности ПК', 'С чего начать обучение?'];

const USE_API = import.meta.env.VITE_ROZA_USE_API !== 'false';

export function RozaChat({
  mini = false,
  gemini = false,
  starters = DEFAULT_STARTERS,
  initialMessages = [],
  placeholder = 'Сообщение для Roza…',
  showChips = true,
}: Props) {
  const [prompt, setPrompt] = useState('');
  const [messages, setMessages] = useState<RozaChatMessage[]>(initialMessages);
  const [typing, setTyping] = useState(false);
  const [sessionId, setSessionId] = useState<string | undefined>();
  const bottomRef = useRef<HTMLDivElement>(null);
  const hasThread = messages.length > 0 || typing;

  useEffect(() => {
    if (!mini || hasThread) {
      bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages, typing, mini, hasThread]);

  async function resolveReply(q: string): Promise<string> {
    if (!USE_API) {
      await new Promise((r) => setTimeout(r, rozaTypingDelayMs()));
      return rozaDemoReply(q);
    }
    try {
      const res = await rozaChat(q, sessionId);
      if (res.sessionId) setSessionId(res.sessionId);
      return res.reply;
    } catch {
      if (import.meta.env.DEV) {
        await new Promise((r) => setTimeout(r, rozaTypingDelayMs()));
        return rozaDemoReply(q);
      }
      return 'Сервис временно недоступен. Попробуйте позже или используйте приложение Roza для Windows.';
    }
  }

  function send(text?: string) {
    const q = (text ?? prompt).trim();
    if (!q || typing) return;
    setPrompt('');
    setMessages((m) => [...m, { role: 'user', text: q }]);
    setTyping(true);

    void resolveReply(q).then((reply) => {
      setMessages((m) => [...m, { role: 'assistant', text: reply }]);
      setTyping(false);
    });
  }

  const avatarSize = mini ? 22 : 32;

  return (
    <section
      className={`roza-chat-shell${mini ? ' roza-chat-mini' : ''}${gemini ? ' roza-chat-gemini' : ''}${hasThread && mini ? ' roza-chat-mini-open' : ''}`}
      aria-label="Чат с Roza"
    >
      {hasThread ? (
        <div className="roza-chat-messages">
          {messages.map((msg, i) => (
            <div key={`${i}-${msg.role}`} className={`roza-chat-row ${msg.role}`}>
              <div className="roza-chat-avatar">
                {msg.role === 'user' ? 'Вы' : <RozaMark variant="ai" size={avatarSize} />}
              </div>
              <div className="roza-chat-bubble">{msg.text}</div>
            </div>
          ))}
          {typing ? (
            <div className="roza-chat-row assistant">
              <div className="roza-chat-avatar">
                <RozaMark variant="ai" size={avatarSize} />
              </div>
              <div className="roza-chat-bubble roza-chat-bubble-typing">
                <span className="roza-chat-typing-text">Печатает</span>
                <span className="roza-chat-typing-dots" aria-hidden>
                  <span />
                  <span />
                  <span />
                </span>
              </div>
            </div>
          ) : null}
          <div ref={bottomRef} />
        </div>
      ) : null}

      <div className="roza-chat-composer">
        {!mini && showChips && starters.length > 0 ? (
          <div className="roza-chat-chips">
            {starters.map((s) => (
              <button key={s} type="button" className="roza-chip" onClick={() => send(s)} disabled={typing}>
                {s}
              </button>
            ))}
          </div>
        ) : null}
        <div className="roza-chat-input-wrap">
          <textarea
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            placeholder={placeholder}
            rows={1}
            disabled={typing}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                send();
              }
            }}
          />
          <button
            type="button"
            className="roza-chat-send"
            onClick={() => send()}
            disabled={typing || !prompt.trim()}
            aria-label="Отправить"
          >
            ↑
          </button>
        </div>
      </div>
    </section>
  );
}
