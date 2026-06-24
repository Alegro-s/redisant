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
            Светлая витрина продукта. Проекты, сборки, статистика и продажи — только в{' '}
            <strong>личном кабинете</strong> после входа.
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

      <section className="cloud-apple-values">
        <article>
          <h2>Для автора игр</h2>
          <p>Синхронизация с Lynx Launcher, хранение сцен и совместная работа — без дублирования на диске.</p>
        </article>
        <article>
          <h2>Для команды</h2>
          <p>Один профиль, роли и доступы. Рабочие экраны не дублируются на этой странице.</p>
        </article>
        <article>
          <h2>Безопасность</h2>
          <p>Данные в контуре вашего проекта. Управление ключами и политиками — в кабинете.</p>
        </article>
      </section>

      <section className="cloud-apple-cta">
        <h2>Всё в личном кабинете</h2>
        <p>Проекты, сборки, отзывы и аналитика открываются после авторизации.</p>
        <a className="cloud-btn-primary" href={LYNX_CABINET_URL}>
          Открыть личный кабинет
        </a>
      </section>

      <p className="cloud-intro-foot">
        <Link href="/cabinet/sign-in">Для разработчиков →</Link>
      </p>
    </main>
  );
}
