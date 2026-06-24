import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { LynxLauncherPreview } from '../components/LynxLauncherPreview';
import { LynxEngineStack } from '../components/LynxEngineStack';
import {
  ENGINE_MANIFEST_URL,
  ENGINE_WEB_DEMO_URL,
  LYNX_CLOUD_SITE_URL,
} from '../config/links';
import { fetchEngineManifest, type EngineManifest } from '../lib/engineManifest';

export function HomePage() {
  const [manifest, setManifest] = useState<EngineManifest | null>(null);

  useEffect(() => {
    void fetchEngineManifest(ENGINE_MANIFEST_URL || undefined).then(setManifest);
  }, []);

  const recommended = manifest?.recommended_version ?? '0.15.0';
  const releases = manifest?.releases ?? [];

  return (
    <div className="lynx-launch-page">
      <section className="lynx-launch-hero">
        <div className="lynx-launch-hero-text">
          <p className="lynx-pill">Хаб Lynx Launcher</p>
          <h1>
            Лаунчер с <em>движком</em>, чатом и сборкой
          </h1>
          <p className="lynx-hero-lead">
            Lynx Engine <strong>{recommended}</strong> — отдельное окно Play, Install Hub с CDN, облачные проекты.
            Launcher для Windows и Android: проекты, редактор сцен, чат, ядро 2D и экспорт игр.
          </p>
          <div className="lynx-hero-btns">
            <Link to="/download" className="lynx-app-cta lynx-cta-lg">
              Скачать
            </Link>
            <a href={ENGINE_WEB_DEMO_URL} className="lynx-app-cta-ghost lynx-cta-lg">
              Редактор в браузере
            </a>
            <Link to="/pricing" className="lynx-app-cta-ghost lynx-cta-lg">
              Подписки
            </Link>
          </div>
        </div>
        <LynxLauncherPreview />
      </section>

      <section className="lynx-launch-engine-stack" aria-label="Архитектура Lynx">
        <h2 className="lynx-launch-feed-title">Launcher → Engine → Build</h2>
        <LynxEngineStack />
      </section>

      <p className="lynx-launch-kicker" aria-hidden>
        ◆ Launcher · Engine · Chat · Build ◆
      </p>

      <section className="lynx-launch-feed" aria-labelledby="lynx-feed-h">
        <h2 id="lynx-feed-h" className="lynx-launch-feed-title">
          Что на Hub
        </h2>

        <article className="lynx-launch-row">
          <div className="lynx-launch-row-meta">
            <span className="lynx-launch-row-num">01</span>
            <h3>Скачать Launcher</h3>
          </div>
          <p>Windows MSI/EXE, Android APK, исходники клиента.</p>
          <Link to="/download" className="lynx-launch-row-action">
            Загрузки →
          </Link>
        </article>

        <article className="lynx-launch-row">
          <div className="lynx-launch-row-meta">
            <span className="lynx-launch-row-num">02</span>
            <h3>Версии движка</h3>
          </div>
          <p>
            Рекомендуется <strong>{recommended}</strong>
            {releases.length > 0
              ? ` · в каталоге ${releases.length} релиз(ов)`
              : ' · манифест с CDN'}
            . Install Hub в Launcher.
          </p>
          <Link to="/download" className="lynx-launch-row-action">
            Пакеты .lynxengine →
          </Link>
        </article>

        <article className="lynx-launch-row">
          <div className="lynx-launch-row-meta">
            <span className="lynx-launch-row-num">03</span>
            <h3>Редактор в вебе</h3>
          </div>
          <p>Flutter Web Engine на Hub — откройте облачный проект из Lynx Cloud.</p>
          <a href={ENGINE_WEB_DEMO_URL} className="lynx-launch-row-action">
            engine-web →
          </a>
        </article>

        <article className="lynx-launch-row">
          <div className="lynx-launch-row-meta">
            <span className="lynx-launch-row-num">04</span>
            <h3>Новости</h3>
          </div>
          <p>Релизы и анонсы — после публикации редакцией.</p>
          <Link to="/blog" className="lynx-launch-row-action lynx-launch-row-action-dim">
            Лента →
          </Link>
        </article>

        <article className="lynx-launch-row">
          <div className="lynx-launch-row-meta">
            <span className="lynx-launch-row-num">05</span>
            <h3>Cloud</h3>
          </div>
          <p>Синхронизация и кабинет разработчика.</p>
          <a href={LYNX_CLOUD_SITE_URL} target="_blank" rel="noreferrer" className="lynx-launch-row-action">
            Открыть ↗
          </a>
        </article>
      </section>

      <footer className="lynx-launch-foot">
        <Link to="/docs">Руководство</Link>
      </footer>
    </div>
  );
}
