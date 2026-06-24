import type { ReactNode } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { LYNX_CLOUD_SITE_URL } from '../config/links';
import { useHubAuth } from '../context/HubAuthContext';
import { getLynxAuthLogin } from '../lib/lynxAuth';
import '../styles/lynx-app.css';
import '../styles/lynx-hub-sell.css';
import '../styles/lynx-ops.css';

const SIGN_IN_PATH = '/sign-in';

const NAV = [
  { to: '/', label: 'Главная', end: true },
  { to: '/projects', label: 'Маркетплейс' },
  { to: '/pricing', label: 'Подписки' },
];

function userLabel(email: string, nickname: string): string {
  if (nickname && nickname !== email) return nickname;
  const local = email.split('@')[0];
  return local || email;
}

export function GamingLayout({ children }: { children: ReactNode }) {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const { user, loading, isAuthenticated, signOut } = useHubAuth();

  function isActive(item: { to: string; end?: boolean }) {
    if (item.end) return pathname === item.to;
    return pathname === item.to || pathname.startsWith(`${item.to}/`);
  }

  const onDocs = pathname.startsWith('/docs');
  const onAccount = pathname.startsWith('/account');

  function handleSignOut() {
    signOut();
    navigate('/sign-in', { replace: true });
  }

  return (
    <div className="lynx-app">
      <header className="lynx-app-header lynx-app-header-hub">
        <Link to="/" className="lynx-app-brand lynx-app-brand-text-only">
          <span className="lynx-app-brand-text">
            Lynx <span className="lynx-app-hub-tag">Hub</span>
          </span>
        </Link>
        <nav className="lynx-app-nav lynx-app-nav-clean" aria-label="Основное меню">
          {NAV.map((item) => (
            <Link key={item.to} to={item.to} className={isActive(item) ? 'active' : undefined}>
              {item.label}
            </Link>
          ))}
          <a
            href={LYNX_CLOUD_SITE_URL}
            target="_blank"
            rel="noreferrer"
            className="lynx-app-nav-cloud"
            title="Lynx Cloud — не Yandex Cloud"
          >
            Lynx Cloud ↗
          </a>
        </nav>
        <div className="lynx-app-header-actions">
          <Link to="/docs" className={`lynx-app-cta-ghost lynx-nav-docs ${onDocs ? 'active' : ''}`}>
            Руководство
          </Link>
          {!loading && isAuthenticated ? (
            <>
              <Link
                to="/account"
                className={`lynx-app-user-chip ${onAccount ? 'is-active' : ''}`}
                title={user?.email ?? getLynxAuthLogin()}
              >
                <span className="lynx-app-user-avatar" aria-hidden>
                  {((user?.nickname || user?.email || getLynxAuthLogin()).trim()[0] ?? '?').toUpperCase()}
                </span>
                <span className="lynx-app-user-label">
                  {user ? userLabel(user.email, user.nickname) : getLynxAuthLogin() || 'Аккаунт'}
                </span>
              </Link>
              <button type="button" className="lynx-app-cta-ghost" onClick={handleSignOut}>
                Выйти
              </button>
            </>
          ) : (
            <Link to={SIGN_IN_PATH} className={`lynx-app-cta-ghost ${pathname === SIGN_IN_PATH ? 'active' : ''}`}>
              Вход
            </Link>
          )}
          <Link to="/download" className="lynx-app-cta">
            Скачать
          </Link>
        </div>
      </header>
      <main className="lynx-app-main lynx-app-main-animated">{children}</main>
      <footer className="lynx-app-footer">
        © Lynx · <Link to="/docs">Руководство</Link>
        {' · '}
        <Link to="/privacy">Конфиденциальность</Link>
        {' · '}
        <Link to="/terms">Условия</Link>
      </footer>
    </div>
  );
}
