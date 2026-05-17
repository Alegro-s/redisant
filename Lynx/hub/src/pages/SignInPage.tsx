import { FormEvent, useEffect, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { LYNX_CABINET_URL } from '../config/links';

function resolveAuthBase(): string {
  const raw = (import.meta.env.VITE_LYNX_AUTH_URL as string | undefined)?.trim();
  if (raw) return raw.replace(/\/$/, '');
  if (import.meta.env.DEV) return '/auth';
  return 'http://127.0.0.1:8090';
}

export function SignInPage() {
  const location = useLocation();
  const [mode, setMode] = useState<'login' | 'register'>(
    location.pathname === '/register' ? 'register' : 'login',
  );
  const [email, setEmail] = useState('');
  const [nickname, setNickname] = useState('');
  const [fullName, setFullName] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    setMode(location.pathname === '/register' ? 'register' : 'login');
  }, [location.pathname]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      if (mode === 'login') {
        const res = await fetch(`${resolveAuthBase()}/login`, {
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
        window.location.href = `${LYNX_CABINET_URL}/dashboard`;
        return;
      }
      const res = await fetch(`${resolveAuthBase()}/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Client-Realm': 'lynx' },
        credentials: 'include',
        body: JSON.stringify({
          email: email.trim().toLowerCase(),
          nickname: nickname.trim(),
          full_name: (fullName || nickname).trim(),
          password,
          phone: null,
          settings: {},
        }),
      });
      const data = (await res.json().catch(() => ({}))) as { status?: string; email?: string; error?: string };
      if (!res.ok) throw new Error(data.error ?? 'Ошибка');
      if (data.status === 'pending_verification') {
        window.location.href = `${LYNX_CABINET_URL}/sign-in/verify?email=${encodeURIComponent(data.email ?? email)}`;
        return;
      }
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
        <h1>{mode === 'login' ? 'Вход' : 'Регистрация'}</h1>
        <p className="lynx-hero-lead">
          Один аккаунт для Lynx Hub, Lynx Cloud и Lynx Launcher. Регистрация — на вкладке ниже.
        </p>
        <form className="lynx-auth-form" onSubmit={onSubmit}>
          <div className="lynx-auth-tabs">
            <button type="button" className={mode === 'login' ? 'active' : ''} onClick={() => setMode('login')}>
              Вход
            </button>
            <button type="button" className={mode === 'register' ? 'active' : ''} onClick={() => setMode('register')}>
              Регистрация
            </button>
          </div>
          <label>
            Email
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="username" />
          </label>
          {mode === 'register' ? (
            <>
              <label>
                Никнейм
                <input value={nickname} onChange={(e) => setNickname(e.target.value)} required minLength={2} />
              </label>
              <label>
                Имя
                <input value={fullName} onChange={(e) => setFullName(e.target.value)} />
              </label>
            </>
          ) : null}
          <label>
            Пароль
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              minLength={mode === 'register' ? 10 : 1}
              autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
            />
          </label>
          {error ? <p className="lynx-auth-error">{error}</p> : null}
          <button type="submit" className="lynx-app-cta lynx-cta-lg" disabled={busy}>
            {busy ? '…' : mode === 'login' ? 'Войти' : 'Зарегистрироваться'}
          </button>
        </form>
        <p className="lynx-auth-back">
          <Link to="/">← На главную</Link>
        </p>
      </section>
    </div>
  );
}
