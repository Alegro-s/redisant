import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import '../styles/waypoint-marketing.css';
import { LINKS } from './links';

type Props = {
  children: ReactNode;
  brand: string;
  brandSub: string;
  variant?: 'club' | 'metric';
  nav?: ReactNode;
  footerNote?: string;
};

export function MarketingLayout({ children, brand, brandSub, variant = 'club', nav, footerNote }: Props) {
  const rootClass = variant === 'metric' ? 'wm-root wm-metric-accent' : 'wm-root';

  return (
    <div className={rootClass}>
      <header className="wm-nav">
        <Link to="/" className="wm-brand">
          <span className="wm-mark" aria-hidden />
          <span>
            <div className="wm-brand-title">{brand}</div>
            <div className="wm-brand-sub">{brandSub}</div>
          </span>
        </Link>
        <nav className="wm-nav-links">
          {nav ?? (
            <>
              <a href={LINKS.metric}>Metric</a>
              <a href={LINKS.lynxHub} target="_blank" rel="noreferrer">
                Lynx
              </a>
              <a href={LINKS.university} target="_blank" rel="noreferrer">
                ТГПУ
              </a>
              <Link to="/login">Войти</Link>
            </>
          )}
        </nav>
      </header>
      <main className="wm-main">{children}</main>
      <footer className="wm-footer">
        <p>
          {footerNote ??
            '© Waypoint · экосистема инструментов для разработки, метрик и образования. Отдельные бренды: Lynx, Roza, ТГПУ.'}
        </p>
      </footer>
    </div>
  );
}
