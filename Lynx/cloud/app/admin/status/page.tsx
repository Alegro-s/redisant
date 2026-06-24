'use client';

import { useEffect, useState } from 'react';
import { checkServiceHealth, lynxApiBase } from '@/lib/adminClient';
import { resolveLynxAuthBase } from '@/lib/authBase';

type Row = { name: string; url: string; ok: boolean | null };

export default function AdminStatusPage() {
  const [rows, setRows] = useState<Row[]>([]);

  useEffect(() => {
    void (async () => {
      const checks: Row[] = [
        { name: 'Lynx API /health', url: `${lynxApiBase()}/health`, ok: null },
        { name: 'Auth API /health', url: `${resolveLynxAuthBase()}/health`, ok: null },
        { name: 'Engine manifest', url: `${lynxApiBase()}/engine/manifest`, ok: null },
        {
          name: 'CDN engine-manifest',
          url: 'https://lynx-hub.ru/dist/downloads/engine-manifest.json',
          ok: null,
        },
      ];
      const out: Row[] = [];
      for (const c of checks) {
        out.push({ ...c, ok: await checkServiceHealth(c.url) });
      }
      setRows(out);
    })();
  }, []);

  return (
    <div className="cloud-admin-page">
      <h1>Статус сервисов</h1>
      <ul className="cloud-admin-list">
        {rows.map((r) => (
          <li key={r.name}>
            <strong>{r.ok === true ? 'OK' : r.ok === false ? 'FAIL' : '…'}</strong> {r.name}
          </li>
        ))}
      </ul>
    </div>
  );
}
