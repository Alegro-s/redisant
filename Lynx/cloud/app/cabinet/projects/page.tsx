'use client';

import { FormEvent, useEffect, useState } from 'react';
import { lynxCabinetFetch } from '@/lib/adminClient';

type Project = {
  id: string;
  name: string;
  description?: string;
  updated_at?: string;
};

export default function CabinetProjectsPage() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [name, setName] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function load() {
    const data = await lynxCabinetFetch<{ projects?: Project[] }>('/me/lynx-cloud/projects');
    setProjects(data.projects ?? []);
  }

  useEffect(() => {
    void load().catch((e) => setError(e instanceof Error ? e.message : 'Ошибка'));
  }, []);

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      await lynxCabinetFetch('/me/lynx-cloud/projects', {
        method: 'POST',
        body: JSON.stringify({ name: name.trim() }),
      });
      setName('');
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Ошибка');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="cloud-admin-page">
      <h1>Проекты</h1>
      <p className="cloud-intro-lead">Облачные проекты Lynx — синхронизация с Launcher.</p>
      {error ? <p className="cloud-auth-error">{error}</p> : null}
      <form className="cloud-admin-field" onSubmit={onCreate}>
        <label>
          Новый проект
          <input value={name} onChange={(e) => setName(e.target.value)} required placeholder="My Game" />
        </label>
        <button type="submit" className="cloud-btn-primary" disabled={busy}>
          {busy ? '…' : 'Создать'}
        </button>
      </form>
      <ul className="lynx-data-table cloud-admin-list">
        {projects.length === 0 ? <li>Нет проектов.</li> : null}
        {projects.map((p) => (
          <li key={p.id}>
            <strong>{p.name}</strong>
            <span>{p.description ?? ''}</span>
            <span>{p.updated_at ? new Date(p.updated_at).toLocaleString() : ''}</span>
            <a
              href={`https://lynx-hub.ru/engine-web/?project=cloud:${encodeURIComponent(p.id)}&projectName=${encodeURIComponent(p.name)}`}
              target="_blank"
              rel="noreferrer"
              className="cloud-btn-primary"
              style={{ marginLeft: '0.75rem', display: 'inline-block' }}
            >
              Открыть в браузере
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}
