import { useEffect, useState } from 'react';
import {
  countMissingRequired,
  fetchHubServiceStatus,
  type ServiceStatusItem,
} from '../lib/hubServiceStatus';

type Props = {
  isOps: boolean;
};

export function HubOpsStatusPanel({ isOps }: Props) {
  const [items, setItems] = useState<ServiceStatusItem[] | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  async function load() {
    setRefreshing(true);
    try {
      setItems(await fetchHubServiceStatus(isOps));
    } finally {
      setRefreshing(false);
    }
  }

  useEffect(() => {
    void load();
  }, [isOps]);

  const missing = items ? countMissingRequired(items) : 0;

  return (
    <section className="lynx-hub-ops-status">
      <div className="lynx-hub-ops-status-head">
        <div>
          <h2>Состояние сервисов</h2>
          <p className="lynx-lead">
            {items === null
              ? 'Проверка…'
              : missing === 0
                ? 'Обязательные компоненты настроены.'
                : `Не настроено обязательных: ${missing}`}
          </p>
        </div>
        <button type="button" className="lynx-app-cta-ghost" onClick={() => void load()} disabled={refreshing}>
          {refreshing ? '…' : 'Обновить'}
        </button>
      </div>

      <ul className="lynx-hub-ops-status-list">
        {(items ?? []).map((item) => (
          <li key={item.id} className={item.ok ? 'is-ok' : item.required ? 'is-fail' : 'is-warn'}>
            <span className="lynx-hub-ops-status-dot" aria-hidden />
            <div>
              <strong>
                {item.title}
                {item.required ? <span className="lynx-hub-ops-req">обязательно</span> : null}
              </strong>
              <p>{item.hint}</p>
            </div>
            <span className="lynx-hub-ops-status-label">{item.ok ? 'OK' : 'Нет'}</span>
          </li>
        ))}
      </ul>

      <details className="lynx-hub-ops-deploy-note">
        <summary>Что прописать на VPS</summary>
        <ol>
          <li>
            <code>/opt/waypoint/smtp.env</code>: <code>JWT_SECRET</code>, <code>POSTGRES_PASSWORD</code>,{' '}
            <code>LYNX_HUB_ADMIN_TOKEN</code>, <code>LYNX_OPS_EMAILS</code>, <code>LYNX_S3_*</code>
          </li>
          <li>
            Пересборка: <code>sudo bash deploy/ecosystem/scripts/server-deploy-lynx-admin.sh</code>
          </li>
          <li>nginx: <code>/auth/</code> → :8090, <code>/lynx/</code> → :8082 на lynx-hub.ru</li>
          <li>Promote nexus: <code>server-promote-lynx-ops.sh</code> для вашего email</li>
        </ol>
      </details>
    </section>
  );
}
