'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';
import {
  fetchLynxProfile,
  getLynxAuthLogin,
  getLynxAuthToken,
  isLynxOps,
} from '@/lib/adminClient';
import { LYNX_HUB_URL } from '@/lib/links';

const NAV = [
  { href: '/cabinet/dashboard', label: 'Обзор' },
  { href: '/cabinet/projects', label: 'Проекты' },
  { href: '/cabinet/builds', label: 'Сборки' },
  { href: '/cabinet/keys', label: 'Ключи' },
];

export function CabinetShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [login, setLogin] = useState('');
  const [ops, setOps] = useState(false);

  useEffect(() => {
    if (pathname?.includes('/sign-in')) {
      setReady(true);
      return;
    }
    const token = getLynxAuthToken();
    if (!token) {
      router.replace('/cabinet/sign-in');
      return;
    }
    setLogin(getLynxAuthLogin());
    void fetchLynxProfile().then((p) => {
      if (p) {
        setLogin(p.email || p.nickname);
        setOps(isLynxOps(p));
      }
      setReady(true);
    });
  }, [pathname, router]);

  if (pathname?.includes('/sign-in')) {
    return <>{children}</>;
  }

  if (!ready) {
    return (
      <main className="cloud-cabinet-page">
        <p>Проверка доступа…</p>
      </main>
    );
  }

  function signOut() {
    localStorage.removeItem('lynx_auth_token');
    localStorage.removeItem('lynx_auth_login');
    router.replace('/cabinet/sign-in');
  }

  return (
    <div className="lynx-ops-shell cloud-admin-shell">
      <aside className="lynx-ops-sidebar cloud-admin-nav">
        <p className="cloud-kicker">Lynx Cloud</p>
        <strong className="lynx-ops-brand cloud-admin-brand">Кабинет</strong>
        <p className="lynx-ops-user">{login}</p>
        <nav>
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={pathname === item.href ? 'is-active' : ''}
            >
              {item.label}
            </Link>
          ))}
        </nav>
        {ops ? (
          <Link href="/admin" className="lynx-ops-link">
            Операции →
          </Link>
        ) : null}
        <a className="lynx-ops-link" href={`${LYNX_HUB_URL}/account`}>
          Lynx Hub
        </a>
        <button type="button" className="lynx-ops-signout" onClick={signOut}>
          Выйти
        </button>
      </aside>
      <main className="lynx-ops-main cloud-admin-main">{children}</main>
    </div>
  );
}
