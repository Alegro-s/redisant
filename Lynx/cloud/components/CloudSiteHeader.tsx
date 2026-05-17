'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { LYNX_CABINET_URL } from '@/lib/links';

function CloudIcon() {
  return (
    <svg className="cloud-icon-svg" width="28" height="28" viewBox="0 0 28 28" aria-hidden>
      <path
        fill="#007AFF"
        d="M7 19.5h14a5 5 0 0 0 .8-9.94A6.2 6.2 0 0 0 8.2 8.5 4.8 4.8 0 0 0 7 19.5z"
      />
    </svg>
  );
}

export function CloudSiteHeader() {
  const router = useRouter();
  const pathname = usePathname();
  const [login, setLogin] = useState<string | null>(null);
  const inCabinet = pathname?.startsWith('/cabinet');

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
            <Link className="cloud-login-btn" href={inCabinet ? '/cabinet/sign-in' : `${LYNX_CABINET_URL}/sign-in`}>
              Войти
            </Link>
          )}
        </nav>
      </div>
    </header>
  );
}
