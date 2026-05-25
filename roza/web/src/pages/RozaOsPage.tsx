import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { RozaMark } from '../components/roza/RozaMark';
import { ROZAOS_ISO_URL, ROZAOS_VERSION } from '../config/links';

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
    body: 'Liza встроена в оболочку: подсказки в терминале, разбор логов, помощь с пакетами — через локальный bridge на 127.0.0.1.',
    tone: 'b',
    ai: true,
    chips: ['Контекст сессии', 'Терминал · IDE', 'Лiza локально', 'Приватность'],
  },
  {
    id: 'inside',
    title: 'Что внутри',
    lead: 'Всё необходимое в одном образе.',
    body: 'Мастер первого запуска, офлайн-установка с USB, XFCE, опциональное шифрование диска и уведомления об обновлениях.',
    tone: 'c',
    ai: false,
    chips: ['OEM wizard', 'Офлайн ISO', 'LUKS2', 'Обновления'],
  },
];

type ReleaseMeta = {
  download_url?: string;
  sha256?: string;
  size_hint?: string;
  version?: string;
};

export function RozaOsPage() {
  const [release, setRelease] = useState<ReleaseMeta | null>(null);
  const isoUrl = (ROZAOS_ISO_URL || release?.download_url || '').trim();
  const version = release?.version || ROZAOS_VERSION;

  useEffect(() => {
    if (ROZAOS_ISO_URL) return;
    fetch('/rozaos-releases.json')
      .then((r) => (r.ok ? r.json() : null))
      .then((j) => {
        const ch = j?.channels?.stable;
        if (ch) setRelease(ch);
      })
      .catch(() => undefined);
  }, []);

  return (
    <main className="roza-main roza-os-present">
      <section className="roza-os-cinema">
        <div className="roza-os-cinema-bg" aria-hidden />
        <div className="roza-os-cinema-inner">
          <p className="roza-hub-waypoint">Waypoint · Roza</p>
          <RozaMark variant="os" size={52} />
          <h1 className="roza-os-wordmark">
            Roza <span className="roza-os-wordmark-os">OS</span>
          </h1>
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
            {ch.ai ? <span className="roza-os-ai-badge">Liza</span> : null}
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
          <h2>rozaOS Kiry {version}</h2>
          <p>
            x86_64 · {release?.size_hint ?? '~2.5 GB'} · Secure Boot: shim при сборке ISO
          </p>
          {isoUrl ? (
            <a className="roza-os-download-btn" href={isoUrl} download>
              Скачать ISO
            </a>
          ) : (
            <button type="button" disabled title="Укажите VITE_ROZAOS_ISO_URL или загрузите ISO в S3">
              Скачать ISO — после публикации
            </button>
          )}
          {release?.sha256 ? (
            <p className="roza-os-sha" style={{ fontSize: 12, marginTop: 8, wordBreak: 'break-all' }}>
              SHA256: {release.sha256}
            </p>
          ) : null}
        </div>
      </section>

      <p className="roza-os-footer-links">
        <Link to="/os/docs">Документация и версии</Link>
        <Link to="/ai">Roza AI</Link>
        <Link to="/">Обзор</Link>
      </p>
    </main>
  );
}
