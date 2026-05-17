'use client';

import { FormEvent, useEffect, useState } from 'react';
import Link from 'next/link';

const ADMIN_KEY = 'lynx_cloud_admin';

export default function LynxCloudAdminPage() {
  const [authed, setAuthed] = useState(false);
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    setAuthed(sessionStorage.getItem(ADMIN_KEY) === '1');
  }, []);

  function onLogin(e: FormEvent) {
    e.preventDefault();
    const expected = process.env.NEXT_PUBLIC_LYNX_CLOUD_ADMIN_PASSWORD ?? 'lynx-admin';
    if (password === expected) {
      sessionStorage.setItem(ADMIN_KEY, '1');
      setAuthed(true);
      setError('');
      return;
    }
    setError('Неверный пароль администратора Cloud.');
  }

  if (!authed) {
    return (
      <main className="cloud-apple cloud-cabinet-page">
        <section className="cloud-cabinet-hero">
          <p className="cloud-kicker">Lynx Cloud</p>
          <h1>Админ-панель</h1>
          <form className="cloud-auth-form" onSubmit={onLogin}>
            <label>
              Пароль
              <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
            </label>
            {error ? <p className="cloud-auth-error">{error}</p> : null}
            <button type="submit" className="cloud-btn-primary">
              Войти
            </button>
          </form>
          <p className="cloud-cabinet-note">
            <Link href="/cabinet">← Кабинет пользователя</Link>
          </p>
        </section>
      </main>
    );
  }

  return (
    <main className="cloud-apple cloud-cabinet-page">
      <section className="cloud-cabinet-hero">
        <p className="cloud-kicker">Lynx Cloud · Admin</p>
        <h1>Управление Cloud</h1>
        <p className="cloud-intro-lead">Сборки, лимиты и модерация — отдельный контур от пользовательского кабинета.</p>
        <ul className="cloud-admin-list">
          <li>Статус API: подключите lynx-api на порту 8082</li>
          <li>Очередь сборок: через Lynx Launcher → Cloud</li>
          <li>Пользователи: auth-api, realm nexus</li>
        </ul>
        <div className="cloud-intro-actions">
          <button
            type="button"
            className="cloud-btn-secondary"
            onClick={() => {
              sessionStorage.removeItem(ADMIN_KEY);
              setAuthed(false);
            }}
          >
            Выйти из админки
          </button>
          <Link className="cloud-btn-secondary" href="/cabinet/dashboard">
            Кабинет
          </Link>
        </div>
      </section>
    </main>
  );
}
