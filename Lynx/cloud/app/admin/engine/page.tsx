'use client';

import { useCallback, useEffect, useState } from 'react';
import { lynxAdminFetch } from '@/lib/adminClient';

type Policy = {
  manifest_url: string | null;
  recommended_version: string | null;
  updated_at: string | null;
};

type Manifest = {
  releases: Array<{
    version: string;
    notes?: string;
    channel?: string;
    artifacts: Record<string, { url: string; sha256?: string }>;
  }>;
  recommended_version?: string | null;
  source?: string | null;
};

export default function AdminEnginePage() {
  const [policy, setPolicy] = useState<Policy | null>(null);
  const [manifest, setManifest] = useState<Manifest | null>(null);
  const [manifestUrl, setManifestUrl] = useState('');
  const [recommended, setRecommended] = useState('');
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setError('');
    try {
      const [p, m] = await Promise.all([
        lynxAdminFetch<Policy>('/admin/engine/policy'),
        lynxAdminFetch<Manifest>('/engine/manifest'),
      ]);
      setPolicy(p);
      setManifest(m);
      setManifestUrl(p.manifest_url ?? '');
      setRecommended(p.recommended_version ?? m.recommended_version ?? '');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Ошибка загрузки');
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function save() {
    setSaving(true);
    setOk('');
    setError('');
    try {
      await lynxAdminFetch('/admin/engine/policy', {
        method: 'PUT',
        body: JSON.stringify({
          manifest_url: manifestUrl.trim(),
          recommended_version: recommended.trim(),
        }),
      });
      setOk('Сохранено');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Ошибка сохранения');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="cloud-admin-page">
      <h1>Engine releases</h1>
      <p className="cloud-intro-lead">Политика поставки и публичный манифест для Launcher / Install Hub.</p>
      {error ? <p className="cloud-auth-error">{error}</p> : null}
      {ok ? <p className="cloud-admin-ok">{ok}</p> : null}

      <label className="cloud-admin-field">
        Manifest URL (HTTPS JSON)
        <input value={manifestUrl} onChange={(e) => setManifestUrl(e.target.value)} />
      </label>
      <label className="cloud-admin-field">
        Recommended version
        <input value={recommended} onChange={(e) => setRecommended(e.target.value)} />
      </label>
      <button type="button" className="cloud-btn-primary" disabled={saving} onClick={() => void save()}>
        {saving ? 'Сохранение…' : 'Сохранить policy'}
      </button>

      {policy?.updated_at ? (
        <p className="cloud-cabinet-note">Обновлено: {new Date(policy.updated_at).toLocaleString()}</p>
      ) : null}

      <h2>Текущий манифест</h2>
      <pre className="cloud-admin-pre">{JSON.stringify(manifest, null, 2)}</pre>
    </div>
  );
}
