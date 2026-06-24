'use client';

import { useEffect, useState } from 'react';
import { lynxCabinetFetch } from '@/lib/adminClient';

export default function CabinetKeysPage() {
  const [ingestKey, setIngestKey] = useState('');
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    void (async () => {
      try {
        const ov = await lynxCabinetFetch<{ ingest_api_key?: string }>('/me/lynx-cloud/overview');
        setIngestKey(ov.ingest_api_key ?? '');
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Ошибка');
      }
    })();
  }, []);

  async function copyKey() {
    if (!ingestKey) return;
    await navigator.clipboard.writeText(ingestKey);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  return (
    <div className="cloud-admin-page">
      <h1>Ключи доступа</h1>
      <p className="cloud-intro-lead">
        Ingest API key для телеметрии, CI и автоматической публикации из Launcher.
      </p>
      {error ? <p className="cloud-auth-error">{error}</p> : null}
      <label className="cloud-admin-field">
        Ingest API key
        <input readOnly value={ingestKey || 'Загрузка…'} />
      </label>
      <button type="button" className="cloud-btn-primary" disabled={!ingestKey} onClick={() => void copyKey()}>
        {copied ? 'Скопировано' : 'Копировать'}
      </button>
      <p className="cloud-cabinet-note" style={{ marginTop: '1rem' }}>
        Не передавайте ключ третьим лицам. Для сброса обратитесь в поддержку Lynx.
      </p>
    </div>
  );
}
