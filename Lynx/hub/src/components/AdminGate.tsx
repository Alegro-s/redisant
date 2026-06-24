import { useEffect, useState, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { fetchLynxProfile, getLynxAuthToken, isLynxOps } from '../lib/lynxAuth';
import { hubAdminConfigured, isHubAdmin, loginHubAdmin, logoutHubAdmin } from '../lib/hubAdminAuth';

export function AdminGate({ children }: { children: ReactNode }) {
  const [authed, setAuthed] = useState(false);
  const [checking, setChecking] = useState(true);
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    void (async () => {
      if (isHubAdmin()) {
        setAuthed(true);
        setChecking(false);
        return;
      }
      const token = getLynxAuthToken();
      if (token) {
        const profile = await fetchLynxProfile();
        if (profile && isLynxOps(profile)) {
          setAuthed(true);
          setChecking(false);
          return;
        }
      }
      setChecking(false);
    })();
  }, []);

  if (checking) {
    return <p className="lynx-admin-loading">Проверка доступа…</p>;
  }

  if (!authed && !hubAdminConfigured()) {
    const token = getLynxAuthToken();
    if (!token) {
      return (
        <div className="lynx-admin-gate">
          <h1>Админ-панель</h1>
          <p className="lynx-lead">Войдите в аккаунт Lynx с ролью NEXUS или задайте VITE_HUB_ADMIN_PASSWORD.</p>
          <Link to="/sign-in" className="lynx-launch-row-action">
            Войти
          </Link>
        </div>
      );
    }
  }

  if (!authed) {
    return (
      <div className="lynx-admin-gate">
        <h1>Вход администратора</h1>
        <p className="lynx-lead">Управление новостями, версиями ядра и контентом Hub.</p>
        <p className="lynx-lead">
          <Link to="/sign-in">Войти аккаунтом NEXUS</Link> или введите пароль разработки.
        </p>
        {hubAdminConfigured() ? (
          <form
            className="lynx-admin-login-form"
            onSubmit={(e) => {
              e.preventDefault();
              if (loginHubAdmin(password)) {
                setAuthed(true);
                setError('');
              } else {
                setError('Неверный пароль');
              }
            }}
          >
            <label>
              Пароль
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
              />
            </label>
            {error ? <p className="lynx-admin-login-error">{error}</p> : null}
            <button type="submit" className="lynx-app-cta">
              Войти
            </button>
          </form>
        ) : null}
        <Link to="/" className="lynx-launch-row-action">
          ← На главную
        </Link>
      </div>
    );
  }

  return (
    <div className="lynx-ops-shell lynx-admin">
      <aside className="lynx-ops-sidebar">
        <p className="lynx-pill">Lynx Hub</p>
        <strong className="lynx-ops-brand">Operations</strong>
        <nav>
          <Link to="/admin">Контент</Link>
          <Link to="/account">Аккаунт</Link>
          <a href="https://lynx-cloud.ru/admin" target="_blank" rel="noreferrer">
            Cloud Admin
          </a>
        </nav>
        {hubAdminConfigured() ? (
          <button
            type="button"
            className="lynx-ops-signout"
            onClick={() => {
              logoutHubAdmin();
              setAuthed(false);
            }}
          >
            Выйти (пароль)
          </button>
        ) : null}
      </aside>
      <main className="lynx-ops-main">{children}</main>
    </div>
  );
}
