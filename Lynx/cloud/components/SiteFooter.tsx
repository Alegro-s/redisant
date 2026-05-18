import { LYNX_HUB_URL, LYNX_CABINET_URL } from '@/lib/links';

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="site-footer-inner">
        <div className="site-footer-brand">
          <svg width="22" height="22" viewBox="0 0 28 28" aria-hidden>
            <path fill="#007AFF" d="M7 19.5h14a5 5 0 0 0 .8-9.94A6.2 6.2 0 0 0 8.2 8.5 4.8 4.8 0 0 0 7 19.5z" />
          </svg>
          <span>Lynx Cloud</span>
        </div>
        <p className="site-footer-tagline">
          Портал экосистемы Lynx: проекты, ядро, сборки. Кабинет разработчика (отзывы, аналитика, редактор) —{' '}
          <a href={LYNX_CABINET_URL}>войти в кабинет Lynx Cloud</a>.
        </p>
        <p className="site-footer-tagline site-footer-tagline-sub">
          Waypoint Metric — отдельный продукт, другой кабинет.
        </p>
        <div className="site-footer-links">
          <a href={LYNX_HUB_URL} target="_blank" rel="noreferrer">
            Lynx Hub — скачать клиент
          </a>
          <span className="site-footer-sep" aria-hidden>
            ·
          </span>
          <a href="/privacy">Конфиденциальность</a>
          <span className="site-footer-sep" aria-hidden>
            ·
          </span>
          <a href="/terms">Условия</a>
        </div>
      </div>
    </footer>
  );
}
