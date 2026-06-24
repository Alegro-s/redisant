import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { LYNX_CABINET_URL } from '../config/links';
import {
  clearLynxAuth,
  fetchLynxProfile,
  getLynxAuthLogin,
  getLynxAuthToken,
  isLynxOps,
  listHubDownloads,
  recordHubDownload,
} from '../lib/lynxAuth';

type CatalogItem = {
  id: string;
  kind?: string;
  title: string;
  description?: string;
  packageUrl?: string;
  version?: string;
  category?: string;
  builtin?: boolean;
};

type Tab = 'marketplace' | 'downloads' | 'messenger';

export function AccountPage() {
  const navigate = useNavigate();
  const [login, setLogin] = useState('');
  const [tab, setTab] = useState<Tab>('marketplace');
  const [items, setItems] = useState<CatalogItem[]>([]);
  const [downloads, setDownloads] = useState(listHubDownloads());
  const [ops, setOps] = useState(false);

  useEffect(() => {
    const token = getLynxAuthToken();
    if (!token) {
      navigate('/sign-in', { replace: true });
      return;
    }
    setLogin(getLynxAuthLogin());
    void fetchLynxProfile().then((p) => {
      if (p) {
        setLogin(p.email || p.nickname);
        setOps(isLynxOps(p));
      }
    });
    fetch('/content/marketplace-catalog.json')
      .then((r) => r.json())
      .then((data: { items?: CatalogItem[] }) => setItems(data.items ?? []))
      .catch(() => setItems([]));
  }, [navigate]);

  function signOut() {
    clearLynxAuth();
    navigate('/sign-in', { replace: true });
  }

  function downloadItem(item: CatalogItem) {
    if (item.builtin) return;
    const url = item.packageUrl;
    if (!url) return;
    recordHubDownload({ id: item.id, title: item.title, url });
    setDownloads(listHubDownloads());
    window.open(url, '_blank', 'noopener,noreferrer');
  }

  return (
    <div className="lynx-ops-shell">
      <aside className="lynx-ops-sidebar">
        <p className="lynx-pill">Lynx Hub</p>
        <strong className="lynx-ops-brand">Аккаунт</strong>
        <p className="lynx-ops-user">{login || '…'}</p>
        <nav>
          <button type="button" className={tab === 'marketplace' ? 'is-active' : ''} onClick={() => setTab('marketplace')}>
            Маркетплейс
          </button>
          <button type="button" className={tab === 'downloads' ? 'is-active' : ''} onClick={() => setTab('downloads')}>
            Мои загрузки
          </button>
          <button type="button" className={tab === 'messenger' ? 'is-active' : ''} onClick={() => setTab('messenger')}>
            Сообщения
          </button>
        </nav>
        {ops ? (
          <Link to="/admin" className="lynx-ops-link">
            Операции →
          </Link>
        ) : null}
        <a className="lynx-ops-link" href={`${LYNX_CABINET_URL}/sign-in`}>
          Кабинет разработчика
        </a>
        <button type="button" className="lynx-ops-signout" onClick={signOut}>
          Выйти
        </button>
      </aside>
      <main className="lynx-ops-main">
        {tab === 'marketplace' && (
          <>
            <h1>Маркетплейс</h1>
            <p className="lynx-lead">Скачивайте пакеты ассетов и шаблоны для Lynx Launcher.</p>
            <div className="lynx-ops-grid">
              {items.map((item) => (
                <article key={item.id} className="lynx-stat-card">
                  <h2>{item.title}</h2>
                  <p>{item.description ?? item.kind ?? ''}</p>
                  {item.version ? <p className="lynx-ops-meta">v{item.version}</p> : null}
                  {item.builtin ? (
                    <p className="lynx-ops-meta">Встроено в Launcher</p>
                  ) : item.packageUrl ? (
                    <button type="button" className="lynx-app-cta" onClick={() => downloadItem(item)}>
                      Скачать
                    </button>
                  ) : (
                    <p className="lynx-ops-meta">Скоро в Cloud</p>
                  )}
                </article>
              ))}
            </div>
          </>
        )}
        {tab === 'downloads' && (
          <>
            <h1>Мои загрузки</h1>
            <p className="lynx-lead">История скачиваний на этом устройстве.</p>
            <ul className="lynx-data-table">
              {downloads.length === 0 ? <li>Пока нет загрузок.</li> : null}
              {downloads.map((d) => (
                <li key={`${d.id}-${d.at}`}>
                  <strong>{d.title}</strong>
                  <span>{new Date(d.at).toLocaleString()}</span>
                  <a href={d.url} target="_blank" rel="noreferrer">
                    Открыть
                  </a>
                </li>
              ))}
            </ul>
          </>
        )}
        {tab === 'messenger' && (
          <>
            <h1>Сообщения</h1>
            <p className="lynx-lead">
              Личные и групповые чаты доступны в <strong>Lynx Launcher</strong> — вкладка «Мессенджер».
            </p>
            <Link to="/download" className="lynx-app-cta lynx-cta-lg">
              Скачать Launcher
            </Link>
          </>
        )}
      </main>
    </div>
  );
}
