'use client';

import { useEffect, useState } from 'react';
import { lynxAdminFetch } from '@/lib/adminClient';

type Project = {
  id: string;
  name?: string;
  title?: string;
  updated_at?: string;
};

export default function AdminProjectsPage() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [error, setError] = useState('');

  useEffect(() => {
    void (async () => {
      try {
        const data = await lynxAdminFetch<{ projects?: Project[] } | Project[]>(
          '/me/lynx-cloud/projects',
        );
        const list = Array.isArray(data) ? data : (data.projects ?? []);
        setProjects(list);
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Ошибка');
      }
    })();
  }, []);

  return (
    <div className="cloud-admin-page">
      <h1>Облачные проекты</h1>
      <p className="cloud-intro-lead">Список проектов текущего staff-аккаунта (NEXUS видит свои / командные).</p>
      {error ? <p className="cloud-auth-error">{error}</p> : null}
      <ul className="cloud-admin-list">
        {projects.length === 0 ? <li>Нет проектов или нет доступа.</li> : null}
        {projects.map((p) => (
          <li key={p.id}>
            <strong>{p.name ?? p.title ?? p.id}</strong>
            {p.updated_at ? ` · ${new Date(p.updated_at).toLocaleString()}` : ''}
          </li>
        ))}
      </ul>
    </div>
  );
}
