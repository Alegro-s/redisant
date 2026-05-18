'use client';

import { FormEvent, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { LYNX_CABINET_URL, LYNX_HUB_URL } from '@/lib/links';
import { resolveLynxAuthBase } from '@/lib/authBase';

type Props = { initialRegister?: boolean };

export function LynxAuthForm({ initialRegister = false }: Props) {
  const router = useRouter();
  const [mode, setMode] = useState<'login' | 'register'>(initialRegister ? 'register' : 'login');
  const [email, setEmail] = useState('');
  const [nickname, setNickname] = useState('');
  const [fullName, setFullName] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setOk('');
    setBusy(true);
    try {
      if (mode === 'login') {
        const res = await fetch(`${resolveLynxAuthBase()}/login`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-Client-Realm': 'lynx' },
          credentials: 'include',
          body: JSON.stringify({ login: email.trim(), password }),
        });
        const data = (await res.json().catch(() => ({}))) as { token?: string; error?: string; error_code?: string; email?: string };
        if (!res.ok) {
          if (data.error_code === 'email_not_verified') {
            router.push(`/cabinet/sign-in/verify?email=${encodeURIComponent(data.email ?? email)}`);
            return;
          }
          throw new Error(data.error ?? 'Ошибка входа');
        }
        if (!data.token) throw new Error('Нет токена');
        localStorage.setItem('lynx_auth_token', data.token);
        localStorage.setItem('lynx_auth_login', email.trim());
        router.push('/cabinet/dashboard');
        return;
      }

      setError('');
      setOk('');
      throw new Error('REGISTER_VIA_LAUNCHER');
    } catch (err) {
      if (err instanceof Error && err.message === 'REGISTER_VIA_LAUNCHER') {
        setOk('');
        setError('');
      } else {
        setError(err instanceof Error ? err.message : 'Ошибка');
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="cloud-auth-form" onSubmit={onSubmit}>
      <div className="cloud-auth-tabs">
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
        <p className="cloud-cabinet-note" style={{ marginBottom: '1rem' }}>
          Регистрация Lynx только в приложении <strong>Lynx Launcher</strong>. На сайте — вход, если аккаунт уже создан.
          <br />
          <a href={`${LYNX_HUB_URL}/download`} target="_blank" rel="noreferrer">
            Скачать Launcher
          </a>
        </p>
      ) : (
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
      )}
      {error ? <p className="cloud-auth-error">{error}</p> : null}
      {ok ? <p className="cloud-auth-ok">{ok}</p> : null}
      {mode === 'login' ? (
        <button type="submit" className="cloud-btn-primary" disabled={busy}>
          {busy ? '…' : 'Войти'}
        </button>
      ) : (
        <a className="cloud-btn-primary" href={`${LYNX_HUB_URL}/download`} style={{ display: 'inline-block', textAlign: 'center' }}>
          Скачать Lynx Launcher
        </a>
      )}
      <p className="cloud-cabinet-note">
        Аккаунт Lynx отделён от Roza AI и Waypoint Metric.{' '}
        <Link href={LYNX_CABINET_URL}>← Кабинет</Link>
      </p>
      <p className="cloud-cabinet-note" style={{ marginTop: '0.75rem', fontSize: '0.85rem' }}>
        <Link href="/privacy">Конфиденциальность</Link>
        {' · '}
        <Link href="/terms">Условия</Link>
      </p>
    </form>
  );
}
