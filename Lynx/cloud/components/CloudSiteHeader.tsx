'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { CloudIcon } from '@/components/CloudIcon';

export function CloudSiteHeader() {
  const router = useRouter();
  const pathname = usePathname();
  const [login, setLogin] = useState<string | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('lynx_auth_token');
    const lg = localStorage.getItem('lynx_auth_login');
    setLogin(token && lg ? lg : null);
  }, [pathname]);

  function signOut() {
    localStorage.removeItem('lynx_auth_token');
    localStorage.removeItem('lynx_auth_login');
    setLogin(null);
    router.push('/cabinet/sign-in');
  }

  return (
    <header className="cloud-header-min">
      <div className="cloud-header-inner">
        <Link href="/" className="cloud-brand-min">
          <CloudIcon />
          Lynx Cloud
        </Link>
        <nav className="cloud-header-nav" aria-label="Аккаунт">
          {login ? (
            <>
              <span className="cloud-header-user" title={login}>
                {login}
              </span>
              <Link className="cloud-login-btn" href="/cabinet/dashboard">
                Кабинет
              </Link>
              <button type="button" className="cloud-login-btn cloud-login-btn-ghost" onClick={signOut}>
                Выйти
              </button>
            </>
          ) : (
            <Link className="cloud-login-btn" href="/cabinet/sign-in">
              Войти
            </Link>
          )}
        </nav>
      </div>
    </header>
  );
}
