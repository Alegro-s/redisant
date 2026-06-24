'use client';

import { useEffect, useState } from 'react';
import { lynxAdminFetch } from '@/lib/adminClient';

type BuildJob = {
  id: string;
  status?: string;
  ref_name?: string;
  label?: string;
  created_at?: string;
};

export default function AdminBuildsPage() {
  const [jobs, setJobs] = useState<BuildJob[]>([]);
  const [error, setError] = useState('');

  useEffect(() => {
    void (async () => {
      try {
        const projects = await lynxAdminFetch<{ id: string }[] | { projects?: { id: string }[] }>(
          '/me/lynx-cloud/projects',
        );
        const list = Array.isArray(projects) ? projects : (projects.projects ?? []);
        const all: BuildJob[] = [];
        for (const p of list.slice(0, 20)) {
          try {
            const builds = await lynxAdminFetch<BuildJob[]>(
              `/me/lynx-cloud/projects/${p.id}/builds`,
            );
            all.push(...builds.map((b) => ({ ...b, label: `${p.id}: ${b.label ?? b.ref_name ?? ''}` })));
          } catch {
            /* skip project */
          }
        }
        setJobs(all);
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Ошибка');
      }
    })();
  }, []);

  return (
    <div className="cloud-admin-page">
      <h1>Очередь сборок</h1>
      <p className="cloud-intro-lead">Последние build jobs по облачным проектам.</p>
      {error ? <p className="cloud-auth-error">{error}</p> : null}
      <ul className="cloud-admin-list">
        {jobs.length === 0 ? <li>Нет сборок.</li> : null}
        {jobs.map((j) => (
          <li key={j.id}>
            <strong>{j.status ?? '—'}</strong> {j.label ?? j.ref_name ?? j.id}
            {j.created_at ? ` · ${new Date(j.created_at).toLocaleString()}` : ''}
          </li>
        ))}
      </ul>
    </div>
  );
}
