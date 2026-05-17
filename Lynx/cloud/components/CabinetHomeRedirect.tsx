'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';

/** /cabinet — сразу в dashboard, если есть сессия. */
export function CabinetHomeRedirect() {
  const router = useRouter();

  useEffect(() => {
    const token = localStorage.getItem('lynx_auth_token');
    if (token) router.replace('/cabinet/dashboard');
  }, [router]);

  return (
    <main className="cloud-apple cloud-cabinet-page">
      <section className="cloud-cabinet-hero">
        <p className="cloud-kicker">Lynx Cloud</p>
        <h1>Личный кабинет</h1>
        <p className="cloud-intro-lead">
          Проекты, сборки, аналитика и ключи API — в контуре Lynx Cloud. Отдельно от Waypoint Metric и Roza AI.
        </p>
        <div className="cloud-intro-actions">
          <Link className="cloud-btn-primary" href="/cabinet/sign-in">
            Войти
          </Link>
          <Link className="cloud-btn-secondary" href="/cabinet/sign-in?mode=register">
            Регистрация
          </Link>
        </div>
      </section>
    </main>
  );
}
