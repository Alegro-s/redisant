import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';

const ROZA_ORIGIN = import.meta.env.VITE_ROZA_URL ?? 'http://localhost:5180';

/** Старые URL /roza/* на Lynx Hub → отдельный сайт Roza */
export function RozaRedirect() {
  const { pathname } = useLocation();

  useEffect(() => {
    const sub = pathname.replace(/^\/roza\/?/, '');
    const target = sub ? `${ROZA_ORIGIN}/${sub}` : ROZA_ORIGIN;
    window.location.replace(target);
  }, [pathname]);

  return (
    <p style={{ padding: 48, textAlign: 'center', fontFamily: 'system-ui' }}>
      Переход на сайт Roza…
    </p>
  );
}
