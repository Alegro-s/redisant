'use client';

import { FormEvent, useRef, useState } from 'react';
import { getLynxAuthToken, lynxAdminFetch } from '@/lib/adminClient';

export default function AdminStoragePage() {
  const [key, setKey] = useState('deploy/lynx/engine/');
  const [msg, setMsg] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  async function onUpload(e: FormEvent) {
    e.preventDefault();
    setError('');
    setMsg('');
    const file = fileRef.current?.files?.[0];
    if (!file) {
      setError('Выберите файл');
      return;
    }
    const objectKey = `${key.replace(/\/$/, '')}/${file.name}`;
    setBusy(true);
    try {
      const presign = await lynxAdminFetch<{
        upload_url: string;
        public_url: string;
        method: string;
      }>('/admin/storage/presign', {
        method: 'POST',
        body: JSON.stringify({ key: objectKey, content_type: file.type || 'application/octet-stream' }),
      });
      const put = await fetch(presign.upload_url, {
        method: presign.method || 'PUT',
        headers: { 'Content-Type': file.type || 'application/octet-stream' },
        body: file,
      });
      if (!put.ok) {
        const form = new FormData();
        form.append('key', objectKey);
        form.append('file', file);
        const token = getLynxAuthToken();
        const up = await fetch(`${process.env.NEXT_PUBLIC_LYNX_API_BASE || '/lynx'}/admin/storage/upload`, {
          method: 'POST',
          headers: token ? { Authorization: `Bearer ${token}` } : {},
          body: form,
        });
        if (!up.ok) throw new Error('Загрузка не удалась');
        const data = (await up.json()) as { public_url?: string };
        setMsg(`Загружено: ${data.public_url ?? objectKey}`);
        return;
      }
      setMsg(`Загружено: ${presign.public_url}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Ошибка');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="cloud-admin-page">
      <h1>Хранилище S3</h1>
      <p className="cloud-intro-lead">
        Загрузка артефактов на twcstorage (префикс deploy/lynx/ или deploy/sites/latest/).
      </p>
      {error ? <p className="cloud-auth-error">{error}</p> : null}
      {msg ? <p className="cloud-admin-ok">{msg}</p> : null}
      <form onSubmit={onUpload}>
        <label className="cloud-admin-field">
          Ключ (папка)
          <input value={key} onChange={(e) => setKey(e.target.value)} />
        </label>
        <label className="cloud-admin-field">
          Файл
          <input ref={fileRef} type="file" />
        </label>
        <button type="submit" className="cloud-btn-primary" disabled={busy}>
          {busy ? 'Загрузка…' : 'Загрузить'}
        </button>
      </form>
    </div>
  );
}
