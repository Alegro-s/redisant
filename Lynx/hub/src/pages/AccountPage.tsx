import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useHubAuth } from '../context/HubAuthContext';
import { ENGINE_WEB_DEMO_URL, LYNX_CABINET_URL } from '../config/links';
import { listHubDownloads, recordHubDownload, getLynxAuthToken } from '../lib/lynxAuth';

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

type Tab = 'overview' | 'marketplace' | 'downloads' | 'messenger';

function displayName(email: string, nickname: string): string {
  if (nickname && nickname !== email) return nickname;
  return email;
}

function userInitial(email: string, nickname: string): string {
  const src = nickname || email;
  return (src.trim()[0] ?? '?').toUpperCase();
}

export function AccountPage() {
  const navigate = useNavigate();
  const { user, loading, isOps, signOut } = useHubAuth();
  const [tab, setTab] = useState<Tab>('overview');
  const [items, setItems] = useState<CatalogItem[]>([]);
  const [downloads, setDownloads] = useState(listHubDownloads());

  useEffect(() => {
    if (!loading && !getLynxAuthToken()) {
      navigate('/sign-in', { replace: true });
    }
  }, [loading, navigate]);

  useEffect(() => {
    fetch('/content/marketplace-catalog.json')
      .then((r) => r.json())
      .then((data: { items?: CatalogItem[] }) => setItems(data.items ?? []))
      .catch(() => setItems([]));
  }, []);

  function handleSignOut() {
    signOut();
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

  if (loading) {
    return (
      <div className="lynx-hub-account">
        <p className="lynx-hub-account-loading">Загрузка профиля…</p>
      </div>
    );
  }

  if (!loading && !getLynxAuthToken()) return null;

  if (!user) {
    return (
      <div className="lynx-hub-account">
        <p className="lynx-hub-account-loading">Загрузка профиля…</p>
      </div>
    );
  }

  const email = user.email;
  const nickname = user.nickname ?? '';
  const name = displayName(email, nickname);

  const tabs: { id: Tab; label: string }[] = [
    { id: 'overview', label: 'Обзор' },
    { id: 'marketplace', label: 'Маркетплейс' },
    { id: 'downloads', label: 'Загрузки' },
    { id: 'messenger', label: 'Сообщения' },
  ];

  return (
    <div className="lynx-hub-account">
      <header className="lynx-hub-account-hero">
        <div className="lynx-hub-account-identity">
          <span className="lynx-hub-account-avatar" aria-hidden>
            {userInitial(email, nickname)}
          </span>
          <div>
            <p className="lynx-pill">Личный кабинет</p>
            <h1>{name}</h1>
            <p className="lynx-hub-account-email">{email}</p>
          </div>
        </div>
        <div className="lynx-hub-account-status">
          <span className="lynx-hub-account-badge">Вы вошли</span>
          {isOps ? <span className="lynx-hub-account-badge lynx-hub-account-badge--ops">NEXUS</span> : null}
          <button type="button" className="lynx-app-cta-ghost" onClick={handleSignOut}>
            Выйти
          </button>
        </div>
      </header>

      <nav className="lynx-hub-account-tabs" aria-label="Разделы аккаунта">
        {tabs.map((t) => (
          <button
            key={t.id}
            type="button"
            className={tab === t.id ? 'is-active' : undefined}
            onClick={() => setTab(t.id)}
          >
            {t.label}
          </button>
        ))}
      </nav>

      {tab === 'overview' && (
        <section className="lynx-hub-account-section">
          <div className="lynx-hub-account-quick">
            <Link to="/download" className="lynx-hub-account-tile">
              <strong>Lynx Launcher</strong>
              <span>Скачать приложение, регистрация и мессенджер</span>
            </Link>
            <a href={`${LYNX_CABINET_URL}/dashboard`} className="lynx-hub-account-tile" target="_blank" rel="noreferrer">
              <strong>Кабинет разработчика</strong>
              <span>Проекты, сборки и аналитика в Lynx Cloud</span>
            </a>
            <button type="button" className="lynx-hub-account-tile" onClick={() => setTab('marketplace')}>
              <strong>Маркетплейс Hub</strong>
              <span>Ассеты и шаблоны для Launcher</span>
            </button>
            {isOps ? (
              <Link to="/admin" className="lynx-hub-account-tile lynx-hub-account-tile--ops">
                <strong>Операции</strong>
                <span>Админ-панель Hub и контент</span>
              </Link>
            ) : null}
          </div>
          <p className="lynx-hub-account-hint">
            Один аккаунт Lynx работает в Hub, Cloud и Launcher. Настройки профиля — в{' '}
            <a href={`${LYNX_CABINET_URL}/dashboard`} target="_blank" rel="noreferrer">
              Lynx Cloud
            </a>
            .
          </p>
        </section>
      )}

      {tab === 'marketplace' && (
        <section className="lynx-hub-account-section">
          <h2>Маркетплейс</h2>
          <p className="lynx-lead">Пакеты ассетов и шаблоны для Lynx Launcher.</p>
          <div className="lynx-marketplace-grid">
            {items.map((item) => (
              <article key={item.id} className="lynx-marketplace-card">
                {item.kind ? <span className="lynx-marketplace-kind">{item.kind}</span> : null}
                <h3>{item.title}</h3>
                <p className="lynx-marketplace-desc">{item.description ?? ''}</p>
                {item.version ? (
                  <p className="lynx-marketplace-meta">
                    <span>v{item.version}</span>
                  </p>
                ) : null}
                {item.builtin ? (
                  <p className="lynx-marketplace-foot">Встроено в Launcher</p>
                ) : item.packageUrl ? (
                  <button type="button" className="lynx-app-cta" onClick={() => downloadItem(item)}>
                    Скачать
                  </button>
                ) : (
                  <p className="lynx-marketplace-foot">Скоро в Cloud</p>
                )}
              </article>
            ))}
          </div>
        </section>
      )}

      {tab === 'downloads' && (
        <section className="lynx-hub-account-section">
          <h2>Мои загрузки</h2>
          <p className="lynx-lead">История скачиваний на этом устройстве.</p>
          <ul className="lynx-hub-downloads">
            {downloads.length === 0 ? <li className="lynx-hub-downloads-empty">Пока нет загрузок.</li> : null}
            {downloads.map((d) => (
              <li key={`${d.id}-${d.at}`}>
                <div>
                  <strong>{d.title}</strong>
                  <span>{new Date(d.at).toLocaleString()}</span>
                </div>
                <a href={d.url} target="_blank" rel="noreferrer" className="lynx-link-accent">
                  Открыть
                </a>
              </li>
            ))}
          </ul>
        </section>
      )}

      {tab === 'messenger' && (
        <section className="lynx-hub-account-section">
          <h2>Сообщения</h2>
          <p className="lynx-lead">
            Личные и групповые чаты доступны в <strong>Lynx Launcher</strong> (вкладка «Мессенджер») —
            для Windows и Android. В браузере Hub работает редактор и облако; мессенджер пока только в
            приложении.
          </p>
          <div className="lynx-hub-account-quick">
            <Link to="/download" className="lynx-hub-account-tile">
              <strong>Скачать Launcher</strong>
              <span>Мессенджер, проекты и кнопка «Работать» с локальным ядром</span>
            </Link>
            <a href={ENGINE_WEB_DEMO_URL} className="lynx-hub-account-tile">
              <strong>Редактор в браузере</strong>
              <span>WASM-ядро без установки .lynxengine</span>
            </a>
          </div>
        </section>
      )}
    </div>
  );
}
