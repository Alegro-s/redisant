import { useEffect, useState, type FormEvent, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { useHubAuth } from '../context/HubAuthContext';
import { getLynxAuthToken } from '../lib/lynxAuth';
import { hubAdminConfigured, isHubAdmin, loginHubAdmin, logoutHubAdmin } from '../lib/hubAdminAuth';

export function AdminGate({ children }: { children: ReactNode }) {
  const { loading, isOps } = useHubAuth();
  const [passwordAuthed, setPasswordAuthed] = useState(isHubAdmin());
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const authed = passwordAuthed || isOps;

  useEffect(() => {
    if (isHubAdmin()) setPasswordAuthed(true);
  }, []);

  if (loading) {
    return (
      <div className="lynx-hub-account">
        <p className="lynx-hub-account-loading">Проверка доступа…</p>
      </div>
    );
  }

  if (!authed) {
    const hasToken = Boolean(getLynxAuthToken());
    return (
      <div className="lynx-launch-page lynx-auth-page-wrap">
        <section className="lynx-auth-panel lynx-hub-ops-gate">
          <p className="lynx-pill">Lynx Hub · Operations</p>
          <h1>Доступ к операциям</h1>
          <p className="lynx-hero-lead">
            Управление новостями, каталогом и Arcade. Нужен аккаунт с ролью <strong>NEXUS</strong> или пароль
            разработки при локальной сборке.
          </p>
          {!hasToken ? (
            <Link to="/sign-in" className="lynx-app-cta lynx-cta-lg">
              Войти в Lynx
            </Link>
          ) : (
            <p className="lynx-auth-error">
              Ваш аккаунт не имеет роли NEXUS. Обратитесь к администратору или войдите другим email.
            </p>
          )}
          {hubAdminConfigured() ? (
            <form
              className="lynx-admin-login-form"
              onSubmit={(e: FormEvent) => {
                e.preventDefault();
                if (loginHubAdmin(password)) {
                  setPasswordAuthed(true);
                  setError('');
                } else {
                  setError('Неверный пароль разработки');
                }
              }}
            >
              <label>
                Пароль разработки (VITE_HUB_ADMIN_PASSWORD)
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                />
              </label>
              {error ? <p className="lynx-admin-login-error">{error}</p> : null}
              <button type="submit" className="lynx-app-cta">
                Войти по паролю
              </button>
            </form>
          ) : null}
          <p className="lynx-auth-back">
            <Link to="/account">← Личный кабинет</Link>
            {' · '}
            <Link to="/">На главную</Link>
          </p>
        </section>
      </div>
    );
  }

  return (
    <>
      {passwordAuthed && hubAdminConfigured() ? (
        <div className="lynx-hub-ops-dev-banner">
          Режим пароля разработки — публикация на API может быть недоступна без NEXUS JWT.
          <button
            type="button"
            onClick={() => {
              logoutHubAdmin();
              setPasswordAuthed(false);
            }}
          >
            Выйти
          </button>
        </div>
      ) : null}
      {children}
    </>
  );
}
