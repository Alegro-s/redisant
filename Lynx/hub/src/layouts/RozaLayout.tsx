import { Link, Outlet, useLocation } from 'react-router-dom';
import '../styles/roza-studio.css';

const NAV = [
  { to: '/roza', label: 'Обзор', end: true },
  { to: '/roza/ai', label: 'Roza AI' },
  { to: '/roza/os', label: 'Roza OS' },
];

export function RozaLayout() {
  const { pathname } = useLocation();

  function isActive(to: string, end?: boolean) {
    if (end) return pathname === to || pathname === `${to}/`;
    return pathname === to || pathname.startsWith(`${to}/`);
  }

  return (
    <div className="roza-studio">
      <header className="roza-top">
        <Link to="/roza" className="roza-brand roza-brand-text-only">
          Roza
        </Link>
        <nav className="roza-nav" aria-label="Roza">
          {NAV.map((item) => (
            <Link key={item.to} to={item.to} className={isActive(item.to, item.end) ? 'active' : undefined}>
              {item.label}
            </Link>
          ))}
        </nav>
      </header>
      <Outlet />
      <footer className="roza-footer">© Roza</footer>
    </div>
  );
}
