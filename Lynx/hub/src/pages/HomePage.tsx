import { Link } from 'react-router-dom';
import { LynxLauncherPreview } from '../components/LynxLauncherPreview';
import { LYNX_CLOUD_SITE_URL } from '../config/links';

export function HomePage() {
  return (
    <div className="lynx-launch-page">
      <section className="lynx-launch-hero">
        <div className="lynx-launch-hero-text">
          <p className="lynx-pill">Хаб Lynx Launcher</p>
          <h1>
            Лаунчер с <em>движком</em>, чатом и сборкой
          </h1>
          <p className="lynx-hero-lead">
            Lynx — не просто сайт: это клиент для Windows и Android. Проекты, редактор сцен, встроенный чат, ядро 2D и
            экспорт игр. Hub — скачивание, новости и версии.
          </p>
          <div className="lynx-hero-btns">
            <Link to="/download" className="lynx-app-cta lynx-cta-lg">
              Скачать
            </Link>
            <Link to="/pricing" className="lynx-app-cta-ghost lynx-cta-lg">
              Подписки
            </Link>
          </div>
        </div>
        <LynxLauncherPreview />
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
          <p>Windows EXE, Android APK, исходники клиента.</p>
          <Link to="/download" className="lynx-launch-row-action">
            Загрузки →
          </Link>
        </article>

        <article className="lynx-launch-row">
          <div className="lynx-launch-row-meta">
            <span className="lynx-launch-row-num">02</span>
            <h3>Новости</h3>
          </div>
          <p>Релизы и анонсы — появятся после публикации редакцией.</p>
          <span className="lynx-launch-muted">Скоро будет</span>
          <Link to="/blog" className="lynx-launch-row-action lynx-launch-row-action-dim">
            Лента →
          </Link>
        </article>

        <article className="lynx-launch-row">
          <div className="lynx-launch-row-meta">
            <span className="lynx-launch-row-num">03</span>
            <h3>Версии движка</h3>
          </div>
          <p>Core и Launcher — changelog на этой витрине.</p>
          <span className="lynx-launch-muted">Скоро будет</span>
        </article>

        <article className="lynx-launch-row">
          <div className="lynx-launch-row-meta">
            <span className="lynx-launch-row-num">04</span>
            <h3>Маркетплейс ассетов</h3>
          </div>
          <p>Спрайты и UI-паки для проектов Lynx.</p>
          <span className="lynx-launch-muted">Скоро будет</span>
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
