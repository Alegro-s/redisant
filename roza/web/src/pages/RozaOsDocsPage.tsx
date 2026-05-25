import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { RozaMark } from '../components/roza/RozaMark';
import { ROZAOS_ISO_URL, ROZAOS_VERSION } from '../config/links';

type ReleaseChannel = {
  version?: string;
  sha256?: string;
  size_hint?: string;
  release_notes?: string;
  iso_filename?: string;
};

const docSections = [
  {
    id: 'start',
    title: 'С чего начать',
    items: [
      'Запись ISO на USB (Ventoy, Rufus, dd).',
      'Первый запуск: мастер на русском, Wi‑Fi, выбор пакетов.',
      'Установка на диск: archinstall или Calamares (roza-install-calamares).',
      'Первый вход: Hyprland, панель Waybar, фон рабочего стола.',
    ],
  },
  {
    id: 'desktop',
    title: 'Рабочий стол',
    items: [
      'SUPER+SPACE — поиск приложений.',
      'SUPER+C — центр управления RozaOS.',
      'Центр управления → «Защита Roza» — мониторинг загрузок.',
      'Магазин приложений и наборы: игры, драйверы, Hyprland.',
    ],
  },
  {
    id: 'security',
    title: 'Безопасность',
    items: [
      'nftables: локальные сервисы только на 127.0.0.1.',
      'Опционально clamav: roza-threat-guard install-deps.',
      'LUKS2 и TPM: roza-luks-tpm-enroll после установки.',
      'roza-security-audit — проверка профиля.',
    ],
  },
  {
    id: 'updates',
    title: 'Обновления',
    items: [
      'roza-update-check — проверка обновлений pacman.',
      'Каналы stable / beta в releases.json.',
      'Офлайн-кэш пакетов на ISO при полной сборке.',
    ],
  },
];

const changelog = [
  { ver: '0.6.0', date: '2026-05', notes: 'Hyprland по умолчанию, мастер OOBE, RozaSecurity Linux, Windows-compat, Liza bridge.' },
  { ver: '0.5.x', date: '2026-04', notes: 'XFCE live, офлайн-установка, улучшения мастера.' },
];

export function RozaOsDocsPage() {
  const [release, setRelease] = useState<ReleaseChannel | null>(null);
  const version = release?.version || ROZAOS_VERSION;

  useEffect(() => {
    fetch('/rozaos-releases.json')
      .then((r) => (r.ok ? r.json() : null))
      .then((j) => setRelease(j?.channels?.stable ?? null))
      .catch(() => undefined);
  }, []);

  return (
    <main className="roza-main roza-os-docs">
      <header className="roza-os-docs-hero">
        <RozaMark variant="os" size={48} />
        <p className="roza-hub-waypoint">Roza OS · документация</p>
        <h1>Документация и версии</h1>
        <p className="roza-os-docs-lead">
          Полный справочник по дистрибутиву: установка, рабочий стол, безопасность и журнал релизов.
        </p>
      </header>

      <section className="roza-os-docs-release">
        <h2>Текущий релиз</h2>
        <dl className="roza-os-docs-dl">
          <dt>Версия</dt>
          <dd>{version}</dd>
          <dt>Размер ISO</dt>
          <dd>{release?.size_hint || '~1.7 GB (быстрая сборка)'}</dd>
          {release?.sha256 ? (
            <>
              <dt>SHA256</dt>
              <dd className="roza-os-docs-mono">{release.sha256}</dd>
            </>
          ) : null}
        </dl>
        {ROZAOS_ISO_URL || release?.iso_filename ? (
          <p>
            <a href={ROZAOS_ISO_URL || '#'} className="roza-os-docs-dl-btn">
              Скачать ISO
            </a>
          </p>
        ) : (
          <p className="roza-os-docs-muted">Ссылка на скачивание появится после публикации на CDN.</p>
        )}
      </section>

      <section className="roza-os-docs-grid">
        {docSections.map((sec) => (
          <article key={sec.id} id={sec.id} className="roza-os-docs-card">
            <h2>{sec.title}</h2>
            <ul>
              {sec.items.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </article>
        ))}
      </section>

      <section className="roza-os-docs-changelog">
        <h2>Журнал версий</h2>
        <div className="roza-os-docs-timeline">
          {changelog.map((c) => (
            <article key={c.ver}>
              <div className="roza-os-docs-ver">{c.ver}</div>
              <div>
                <time>{c.date}</time>
                <p>{c.notes}</p>
              </div>
            </article>
          ))}
        </div>
      </section>

      <p className="roza-ai-footer-links">
        <Link to="/os">Обзор Roza OS</Link>
        <Link to="/">На главную Roza</Link>
      </p>
    </main>
  );
}
