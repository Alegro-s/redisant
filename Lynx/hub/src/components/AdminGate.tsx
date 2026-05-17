import { useState, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { hubAdminConfigured, isHubAdmin, loginHubAdmin, logoutHubAdmin } from '../lib/hubAdminAuth';

export function AdminGate({ children }: { children: ReactNode }) {
  const [authed, setAuthed] = useState(isHubAdmin);
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  if (!hubAdminConfigured()) {
    return (
      <div className="lynx-admin-gate">
        <h1>Админ-панель</h1>
        <p className="lynx-lead">Доступ не настроен. Задайте VITE_HUB_ADMIN_PASSWORD в окружении сборки.</p>
        <Link to="/" className="lynx-launch-row-action">
          ← На главную
        </Link>
      </div>
    );
  }

  if (!authed) {
    return (
      <div className="lynx-admin-gate">
        <h1>Вход администратора</h1>
        <p className="lynx-lead">Управление новостями, версиями ядра и контентом Hub — только для админов.</p>
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
        <Link to="/" className="lynx-launch-row-action">
          ← На главную
        </Link>
      </div>
    );
  }

  return (
    <>
      <div className="lynx-admin-bar">
        <span>Режим администратора</span>
        <button
          type="button"
          className="lynx-btn-outline"
          onClick={() => {
            logoutHubAdmin();
            setAuthed(false);
          }}
        >
          Выйти
        </button>
      </div>
      {children}
    </>
  );
}
