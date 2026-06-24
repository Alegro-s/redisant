'use client';

import { useEffect, useState } from 'react';
import { lynxCabinetFetch } from '@/lib/adminClient';

type Build = {
  id: string;
  project_id: string;
  status: string;
  label?: string;
  ref_name?: string;
  created_at: string;
  finished_at?: string;
};

export default function CabinetBuildsPage() {
  const [builds, setBuilds] = useState<Build[]>([]);
  const [error, setError] = useState('');

  useEffect(() => {
    void (async () => {
      try {
        const data = await lynxCabinetFetch<{ builds?: Build[] } | Build[]>('/me/lynx-cloud/builds');
        setBuilds(Array.isArray(data) ? data : (data.builds ?? []));
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Ошибка');
      }
    })();
  }, []);

  return (
    <div className="cloud-admin-page">
      <h1>Сборки</h1>
      <p className="cloud-intro-lead">История облачных сборок ваших проектов.</p>
      {error ? <p className="cloud-auth-error">{error}</p> : null}
      <ul className="lynx-data-table cloud-admin-list">
        {builds.length === 0 ? <li>Нет сборок.</li> : null}
        {builds.map((b) => (
          <li key={b.id}>
            <strong>{b.label ?? b.ref_name ?? b.id.slice(0, 8)}</strong>
            <span>{b.status}</span>
            <span>{new Date(b.created_at).toLocaleString()}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
