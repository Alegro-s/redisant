import Link from 'next/link';
import { LYNX_CABINET_URL, LYNX_HUB_URL } from '@/lib/links';

export default function Home() {
  return (
    <main className="cloud-apple">
      <section className="cloud-apple-hero">
        <div className="cloud-apple-copy">
          <p className="cloud-kicker">Lynx Cloud</p>
          <h1>
            Облако,
            <br />
            которое работает для вас.
          </h1>
          <p className="cloud-intro-lead">
            Проекты, сборки и синхронизация с Lynx Launcher — в личном кабинете после входа.
          </p>
          <div className="cloud-intro-actions">
            <a className="cloud-btn-primary" href={LYNX_CABINET_URL}>
              Войти в кабинет
            </a>
            <a className="cloud-btn-secondary" href={LYNX_HUB_URL} target="_blank" rel="noreferrer">
              Lynx Hub
            </a>
          </div>
        </div>
        <div className="cloud-apple-visual" aria-hidden>
          <div className="cloud-device cloud-device-front">
            <div className="cloud-ui-bar" />
            <p className="cloud-ui-caption">Личный кабинет</p>
            <div className="cloud-ui-rows">
              <span />
              <span />
              <span />
            </div>
          </div>
        </div>
      </section>

      <section className="cloud-apple-cta">
        <h2>Проекты и сборки в одном кабинете</h2>
        <p>Синхронизация с Launcher, ключи API и облачные build jobs.</p>
        <a className="cloud-btn-primary" href={LYNX_CABINET_URL}>
          Открыть личный кабинет
        </a>
      </section>

      <p className="cloud-intro-foot">
        <Link href="/cabinet/sign-in">Вход для разработчиков →</Link>
      </p>
    </main>
  );
}
