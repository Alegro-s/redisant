import { useEffect } from 'react';
import { Link, Outlet, useLocation } from 'react-router-dom';
import '../styles/roza-studio.css';

const NAV = [
  { to: '/', label: 'Обзор', end: true },
  { to: '/ai', label: 'Roza AI' },
  { to: '/os', label: 'Roza OS' },
];

function AccountIcon() {
  return (
    <svg className="roza-nav-account-icon" viewBox="0 0 24 24" fill="none" aria-hidden>
      <circle cx="12" cy="8" r="3.25" stroke="currentColor" strokeWidth="1.75" />
      <path
        d="M6.5 19.5c.6-2.8 2.9-4.5 5.5-4.5s4.9 1.7 5.5 4.5"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
      />
    </svg>
  );
}

const PAGE_TITLES: Record<string, string> = {
  '/': 'Roza AI — обзор',
  '/ai': 'Roza AI — чат',
  '/os': 'Roza OS',
  '/account': 'Roza AI — аккаунт',
  '/verify-email': 'Roza AI — подтверждение почты',
};

export function RozaLayout() {
  const { pathname } = useLocation();

  useEffect(() => {
    const base = pathname.replace(/\/$/, '') || '/';
    document.title = PAGE_TITLES[base] ?? 'Roza AI — Waypoint';
  }, [pathname]);

  function isActive(to: string, end?: boolean) {
    if (end) return pathname === to || pathname === `${to}/`;
    return pathname === to || pathname.startsWith(`${to}/`);
  }

  return (
    <div className="roza-studio">
      <header className="roza-top roza-top-compact">
        <Link to="/" className="roza-brand roza-brand-text-only">
          <span className="roza-brand-name">Roza</span>
        </Link>
        <nav className="roza-nav" aria-label="Roza">
          {NAV.map((item) => (
            <Link key={item.to} to={item.to} className={isActive(item.to, item.end) ? 'active' : undefined}>
              {item.label}
            </Link>
          ))}
          <Link
            to="/account"
            className={`roza-nav-account${pathname.startsWith('/account') ? ' active' : ''}`}
            aria-label="Личный кабинет Roza"
            title="Личный кабинет Roza"
          >
            <AccountIcon />
          </Link>
        </nav>
      </header>
      <Outlet />
      <footer className="roza-footer">© Waypoint · Roza</footer>
    </div>
  );
}
