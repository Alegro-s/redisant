import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { RozaMark } from '../../components/roza/RozaMark';

const ROZAOS_ISO_URL = import.meta.env.VITE_ROZAOS_ISO_URL ?? '';
const ROZAOS_VERSION = import.meta.env.VITE_ROZAOS_VERSION ?? '0.6.0';

const chapters = [
  {
    id: 'why',
    title: 'Зачем Roza OS',
    lead: 'Единая среда вместо десятка разрозненных инструментов.',
    body: 'Предсказуемые обновления, локальные репозитории и политика данных в контуре РФ — для команд, которым важен контроль над рабочим местом разработчика.',
    tone: 'a',
  },
  {
    id: 'inside',
    title: 'Что внутри',
    lead: 'Всё необходимое в одном образе.',
    body: 'Модульное ядро, терминал, IDE, менеджер пакетов и сетевой стек. Без лишних пакетов на старте — только то, что нужно для ежедневной работы.',
    tone: 'b',
    chips: ['Ядро stable', 'Терминал · IDE', 'Пакеты', 'Сеть'],
  },
  {
    id: 'how',
    title: 'Как устроено',
    lead: 'Установка и обновления без сюрпризов.',
    body: 'USB или виртуальная машина, мастер профиля, подписанные каналы обновлений. Ядро обновляется отдельно от домашнего каталога пользователя.',
    tone: 'c',
  },
];

export function RozaOsPage() {
  const [isoUrl, setIsoUrl] = useState(ROZAOS_ISO_URL);

  useEffect(() => {
    if (ROZAOS_ISO_URL) return;
    fetch('https://waypointclub.ru/rozaos-releases.json')
      .then((r) => (r.ok ? r.json() : null))
      .then((j) => {
        const u = j?.channels?.stable?.download_url;
        if (u) setIsoUrl(u);
      })
      .catch(() => undefined);
  }, []);

  return (
    <main className="roza-main roza-os-present">
      <section className="roza-os-cinema">
        <div className="roza-os-cinema-bg" aria-hidden />
        <div className="roza-os-cinema-inner">
          <RozaMark variant="os" size={52} />
          <h1>Roza OS</h1>
          <p className="roza-os-cinema-tag">Дистрибутив для разработки</p>
        </div>
      </section>

      {chapters.map((ch, i) => (
        <section
          key={ch.id}
          className={`roza-os-chapter ${i % 2 === 1 ? 'alt' : ''}`}
          id={ch.id}
          style={{ animationDelay: `${i * 0.12}s` }}
        >
          <div className="roza-os-chapter-text">
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
            <div className="roza-os-float-ui u1" />
            <div className="roza-os-float-ui u2" />
            <div className="roza-os-float-ui u3" />
          </div>
        </section>
      ))}

      <section className="roza-os-release-stage">
        <div className="roza-os-release-card">
          <RozaMark variant="os" size={36} />
          <h2>rozaOS Kiry {ROZAOS_VERSION}</h2>
          <p>x86_64 · ~2.5 GB · офлайн-установка с USB · Liza AI</p>
          {isoUrl ? (
            <a className="roza-os-download-btn" href={isoUrl} download>
              Скачать ISO
            </a>
          ) : (
            <button type="button" disabled>
              Скачать ISO — после публикации
            </button>
          )}
        </div>
      </section>

      <p className="roza-os-footer-links">
        <Link to="/roza/ai">Roza AI</Link>
        <Link to="/roza">Обзор</Link>
      </p>
    </main>
  );
}
