import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { usePageMeta } from '../hooks/usePageMeta';

type Check = { name: string; url: string; ok?: boolean; ms?: number };

const DEFAULT_CHECKS: Check[] = [
  { name: 'Auth API', url: '/auth/health' },
  { name: 'Waypoint API', url: '/api/health' },
];

export function EcosystemStatusPage() {
  const [checks, setChecks] = useState<Check[]>(DEFAULT_CHECKS);

  usePageMeta({
    title: 'Статус экосистемы Waypoint',
    description: 'Доступность auth-api и waypoint-api.',
  });

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const next = await Promise.all(
        DEFAULT_CHECKS.map(async (c) => {
          const t0 = performance.now();
          try {
            const r = await fetch(c.url, { credentials: 'omit' });
            return { ...c, ok: r.ok, ms: Math.round(performance.now() - t0) };
          } catch {
            return { ...c, ok: false, ms: Math.round(performance.now() - t0) };
          }
        }),
      );
      if (!cancelled) setChecks(next);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div style={{ minHeight: '100vh', padding: '2rem', fontFamily: 'Inter, sans-serif', background: '#0d0d12', color: '#eee' }}>
      <h1>Статус сервисов</h1>
      <p style={{ color: '#888' }}>
        Публичная проверка API. <Link to="/" style={{ color: '#7eb8ff' }}>На главную</Link>
      </p>
      <table style={{ width: '100%', maxWidth: 480, marginTop: '1.5rem', borderCollapse: 'collapse' }}>
        <thead>
          <tr>
            <th align="left">Сервис</th>
            <th align="left">Статус</th>
            <th align="right">мс</th>
          </tr>
        </thead>
        <tbody>
          {checks.map((c) => (
            <tr key={c.name}>
              <td>{c.name}</td>
              <td style={{ color: c.ok ? '#4ade80' : '#f87171' }}>{c.ok ? 'OK' : 'Недоступен'}</td>
              <td align="right">{c.ms ?? '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
