'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { LYNX_HUB_URL } from '@/lib/links';

export default function LynxCabinetDashboardPage() {
  const router = useRouter();
  const [login, setLogin] = useState('');

  useEffect(() => {
    const token = localStorage.getItem('lynx_auth_token');
    const lg = localStorage.getItem('lynx_auth_login') ?? '';
    if (!token) {
      router.replace('/cabinet/sign-in');
      return;
    }
    setLogin(lg);
  }, [router]);

  function signOut() {
    localStorage.removeItem('lynx_auth_token');
    localStorage.removeItem('lynx_auth_login');
    router.replace('/cabinet/sign-in');
  }

  return (
    <main className="cloud-apple cloud-cabinet-page">
      <section className="cloud-cabinet-hero">
        <p className="cloud-kicker">Lynx Cloud</p>
        <h1>Кабинет{login ? `: ${login}` : ''}</h1>
        <p className="cloud-intro-lead">Проекты, сборки и ключи доступа — в одном кабинете. Тот же аккаунт, что в Lynx Launcher.</p>
        <div className="cloud-intro-cards">
          <article>
            <h2>Проекты</h2>
            <p>Синхронизация с Lynx Launcher и облачные сборки.</p>
          </article>
          <article>
            <h2>Ключи доступа</h2>
            <p>Для автоматической сборки и публикации игр.</p>
          </article>
          <article>
            <h2>Админ</h2>
            <p>
              <Link href="/admin">Панель Lynx Cloud</Link> (отдельный вход).
            </p>
          </article>
        </div>
        <div className="cloud-intro-actions">
          <a className="cloud-btn-secondary" href={LYNX_HUB_URL}>
            Lynx Hub
          </a>
          <button type="button" className="cloud-btn-secondary" onClick={signOut}>
            Выйти
          </button>
          <Link className="cloud-btn-secondary" href="/">
            Витрина
          </Link>
        </div>
      </section>
    </main>
  );
}
