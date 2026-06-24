import { FormEvent, useState } from 'react';
import { Link } from 'react-router-dom';
import { LYNX_CABINET_URL } from '../config/links';
import { resolveLynxAuthBase } from '../utils/authBase';

export function SignInPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      const res = await fetch(`${resolveLynxAuthBase()}/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Client-Realm': 'lynx' },
        credentials: 'include',
        body: JSON.stringify({ login: email.trim(), password }),
      });
      const data = (await res.json().catch(() => ({}))) as {
        token?: string;
        error?: string;
        error_code?: string;
        email?: string;
      };
      if (!res.ok) {
        if (data.error_code === 'email_not_verified') {
          window.location.href = `${LYNX_CABINET_URL}/sign-in/verify?email=${encodeURIComponent(data.email ?? email)}`;
          return;
        }
        throw new Error(data.error ?? 'Ошибка входа');
      }
      if (!data.token) throw new Error('Нет токена');
      localStorage.setItem('lynx_auth_token', data.token);
      localStorage.setItem('lynx_auth_login', email.trim());
      window.location.href = `${LYNX_CABINET_URL.replace(/\/$/, '')}/dashboard`;
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Ошибка');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="lynx-launch-page lynx-auth-page-wrap">
      <section className="lynx-auth-panel">
        <p className="lynx-pill">Lynx · аккаунт</p>
        <h1>Вход</h1>
        <p className="lynx-hero-lead">
          Один аккаунт Lynx для Hub, Cloud и Launcher. Если вы уже регистрировались в{' '}
          <strong>Lynx Launcher</strong> — войдите здесь. Новый аккаунт создаётся только в приложении.
        </p>
        <form className="lynx-auth-form" onSubmit={onSubmit}>
          <label>
            Email
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="username" />
          </label>
          <label>
            Пароль
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              autoComplete="current-password"
            />
          </label>
          {error ? <p className="lynx-auth-error">{error}</p> : null}
          <button type="submit" className="lynx-app-cta lynx-cta-lg" disabled={busy}>
            {busy ? '…' : 'Войти'}
          </button>
        </form>
        <p className="lynx-auth-back" style={{ marginTop: '1rem' }}>
          <Link to="/download" className="lynx-link-accent">
            Скачать Lynx Launcher → регистрация
          </Link>
        </p>
        <p className="lynx-auth-back" style={{ fontSize: '0.85rem', color: 'var(--lynx-muted)' }}>
          <Link to="/privacy">Конфиденциальность</Link>
          {' · '}
          <Link to="/terms">Условия</Link>
        </p>
        <p className="lynx-auth-back">
          <Link to="/">← На главную</Link>
        </p>
      </section>
    </div>
  );
}
