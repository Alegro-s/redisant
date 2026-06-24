'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { fetchLynxProfile, getLynxAuthToken, isLynxOps } from '@/lib/adminClient';

const NAV = [
  { href: '/admin/engine', label: 'Engine' },
  { href: '/admin/storage', label: 'Хранилище' },
  { href: '/admin/projects', label: 'Проекты' },
  { href: '/admin/builds', label: 'Сборки' },
  { href: '/admin/status', label: 'Статус' },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [denied, setDenied] = useState(false);

  useEffect(() => {
    if (pathname === '/admin/login') {
      setReady(true);
      return;
    }
    const token = getLynxAuthToken();
    if (!token) {
      router.replace('/admin/login');
      return;
    }
    void fetchLynxProfile().then((p) => {
      if (!p || !isLynxOps(p)) {
        setDenied(true);
        router.replace('/cabinet/dashboard?denied=ops');
        return;
      }
      setReady(true);
    });
  }, [pathname, router]);

  if (pathname === '/admin/login') {
    return <>{children}</>;
  }

  if (denied) {
    return null;
  }

  if (!ready) {
    return (
      <main className="cloud-admin-shell">
        <p>Проверка доступа…</p>
      </main>
    );
  }

  return (
    <div className="lynx-ops-shell cloud-admin-shell">
      <aside className="lynx-ops-sidebar cloud-admin-nav">
        <p className="cloud-kicker">Lynx Cloud</p>
        <strong className="lynx-ops-brand cloud-admin-brand">Operations</strong>
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
        <Link href="/cabinet/dashboard" className="cloud-admin-back">
          Кабинет
        </Link>
      </aside>
      <main className="lynx-ops-main cloud-admin-main">{children}</main>
    </div>
  );
}
