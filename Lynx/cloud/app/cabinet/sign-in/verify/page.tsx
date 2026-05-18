'use client';

import { FormEvent, Suspense, useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { resolveLynxAuthBase } from '@/lib/authBase';

export default function LynxVerifyEmailPage() {
  return (
    <Suspense fallback={<main className="cloud-apple cloud-cabinet-page"><p>Подтверждение почты…</p></main>}>
      <LynxVerifyEmailForm />
    </Suspense>
  );
}

function LynxVerifyEmailForm() {
  const router = useRouter();
  const params = useSearchParams();
  const email = params.get('email') ?? '';
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      const res = await fetch(`${resolveLynxAuthBase()}/auth/register/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Client-Realm': 'lynx' },
        credentials: 'include',
        body: JSON.stringify({ email: email.trim().toLowerCase(), code: code.trim() }),
      });
      const data = (await res.json().catch(() => ({}))) as { token?: string; error?: string };
      if (!res.ok) throw new Error(data.error ?? 'Неверный код');
      if (!data.token) throw new Error('Нет токена');
      localStorage.setItem('lynx_auth_token', data.token);
      localStorage.setItem('lynx_auth_login', email.trim());
      router.push('/cabinet/dashboard');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Ошибка');
    } finally {
      setBusy(false);
    }
  }

  async function resend() {
    setError('');
    setOk('');
    setBusy(true);
    try {
      const res = await fetch(`${resolveLynxAuthBase()}/auth/register/resend`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Client-Realm': 'lynx' },
        body: JSON.stringify({ email: email.trim().toLowerCase() }),
      });
      const data = (await res.json().catch(() => ({}))) as { error?: string };
      if (!res.ok) throw new Error(data.error ?? 'Не удалось отправить');
      setOk('Код отправлен на почту');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Ошибка');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="cloud-apple cloud-cabinet-page">
      <section className="cloud-cabinet-hero">
        <p className="cloud-kicker">Lynx Cloud</p>
        <h1>Подтверждение почты</h1>
        <p className="cloud-intro-lead">Код отправлен на {email || 'ваш email'}.</p>
        <form className="lynx-auth-form" onSubmit={onSubmit}>
          <label>
            Код из письма
            <input value={code} onChange={(e) => setCode(e.target.value)} required maxLength={8} />
          </label>
          {error && <p className="lynx-auth-error">{error}</p>}
          {ok && <p className="lynx-auth-ok">{ok}</p>}
          <button type="submit" className="cloud-btn-primary" disabled={busy}>
            {busy ? '…' : 'Подтвердить'}
          </button>
        </form>
        <div className="cloud-intro-actions">
          <button type="button" className="cloud-btn-secondary" onClick={resend} disabled={busy}>
            Отправить снова
          </button>
          <Link className="cloud-btn-secondary" href="/cabinet/sign-in">
            ← Вход
          </Link>
        </div>
      </section>
    </main>
  );
}

