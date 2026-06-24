import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { HubOpsStatusPanel } from '../components/HubOpsStatusPanel';
import { useHubAuth } from '../context/HubAuthContext';
import type { HubContent } from '../lib/hubContent';
import { loadHubContent, saveHubContentOverride } from '../lib/hubContent';
import {
  fetchMarketplaceCatalogFromApi,
  hubApiConfigured,
  saveHubContentToApi,
  saveMarketplaceCatalogToApi,
  uploadArcadeCart,
} from '../lib/hubApi';
import {
  ENGINE_MANIFEST_URL,
  LYNX_LAUNCHER_APK_URL,
  LYNX_LAUNCHER_EXE_URL,
} from '../config/links';

type Tab = 'status' | 'news' | 'engine' | 'store' | 'arcade' | 'releases';

const TABS: { id: Tab; label: string }[] = [
  { id: 'status', label: 'Статус' },
  { id: 'news', label: 'Новости' },
  { id: 'engine', label: 'Движок' },
  { id: 'store', label: 'Магазин' },
  { id: 'arcade', label: 'Аркада' },
  { id: 'releases', label: 'Релизы' },
];

export function AdminPage() {
  const { user, isOps } = useHubAuth();
  const [content, setContent] = useState<HubContent | null>(null);
  const [saved, setSaved] = useState(false);
  const [saveError, setSaveError] = useState('');
  const [tab, setTab] = useState<Tab>('status');
  const [catalogJson, setCatalogJson] = useState('');
  const [arcadeTitle, setArcadeTitle] = useState('');
  const [arcadeCartId, setArcadeCartId] = useState('');
  const [arcadeTags, setArcadeTags] = useState('arcade,puzzle');
  const [arcadeMsg, setArcadeMsg] = useState('');
  const cartFileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    loadHubContent().then(setContent);
    fetchMarketplaceCatalogFromApi().then((j) => {
      if (j) setCatalogJson(j);
      else {
        fetch('/content/marketplace-catalog.json')
          .then((r) => r.text())
          .then(setCatalogJson)
          .catch(() => setCatalogJson('{}'));
      }
    });
  }, []);

  if (!content) {
    return (
      <div className="lynx-hub-account">
        <p className="lynx-hub-account-loading">Загрузка…</p>
      </div>
    );
  }

  function updateNews(i: number, field: 'title' | 'body' | 'date', value: string) {
    setContent((c) => {
      if (!c) return c;
      const news = [...c.news];
      news[i] = { ...news[i], [field]: value };
      return { ...c, news };
    });
    setSaved(false);
  }

  function addNews() {
    setContent((c) => {
      if (!c) return c;
      return {
        ...c,
        news: [
          {
            slug: `post-${Date.now()}`,
            title: 'Новая запись',
            date: new Date().toISOString().slice(0, 10),
            body: '',
          },
          ...c.news,
        ],
      };
    });
    setSaved(false);
  }

  function updateCore(i: number, field: 'label' | 'version' | 'note', value: string) {
    setContent((c) => {
      if (!c) return c;
      const engineCores = [...c.engineCores];
      engineCores[i] = { ...engineCores[i], [field]: value };
      return { ...c, engineCores };
    });
    setSaved(false);
  }

  async function handleSave() {
    if (!content) return;
    setSaveError('');
    saveHubContentOverride(content);
    if (hubApiConfigured()) {
      const ok = await saveHubContentToApi(content);
      if (!ok) {
        setSaveError('Локально сохранено; API отклонил запрос — см. вкладку «Статус».');
        setSaved(false);
        return;
      }
    } else {
      setSaveError('API не настроен — только localStorage браузера.');
      setSaved(false);
      return;
    }
    setSaved(true);
  }

  async function handleSaveCatalog() {
    setSaveError('');
    if (!hubApiConfigured()) {
      setSaveError('Войдите как NEXUS или задайте VITE_HUB_ADMIN_TOKEN при сборке Hub.');
      return;
    }
    const ok = await saveMarketplaceCatalogToApi(catalogJson);
    if (!ok) {
      setSaveError('Не удалось сохранить каталог — проверьте токен и lynx-api.');
      return;
    }
    setSaved(true);
  }

  async function handleUploadCart() {
    setArcadeMsg('');
    const file = cartFileRef.current?.files?.[0];
    if (!file) {
      setArcadeMsg('Выберите файл .lynxcart');
      return;
    }
    const title = arcadeTitle.trim() || file.name.replace(/\.lynxcart$/i, '');
    const result = await uploadArcadeCart(file, {
      title,
      cartId: arcadeCartId.trim() || undefined,
      tags: arcadeTags,
    });
    setArcadeMsg(result.ok ? `OK: ${result.message} (id: ${result.id})` : `Ошибка: ${result.message}`);
  }

  const displayEmail = user?.email ?? '';

  return (
    <div className="lynx-hub-account lynx-hub-ops">
      <header className="lynx-hub-account-hero">
        <div className="lynx-hub-account-identity">
          <span className="lynx-hub-account-avatar" aria-hidden>
            OP
          </span>
          <div>
            <p className="lynx-pill">Operations</p>
            <h1>Операции Hub</h1>
            <p className="lynx-hub-account-email">{displayEmail || 'Администратор'}</p>
          </div>
        </div>
        <div className="lynx-hub-account-status">
          <span className="lynx-hub-account-badge lynx-hub-account-badge--ops">NEXUS</span>
          <Link to="/account" className="lynx-app-cta-ghost">
            Аккаунт
          </Link>
          <a href="https://lynx-cloud.ru/admin" target="_blank" rel="noreferrer" className="lynx-app-cta-ghost">
            Cloud Admin ↗
          </a>
        </div>
      </header>

      <nav className="lynx-hub-account-tabs" aria-label="Разделы операций">
        {TABS.map((t) => (
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

      {(tab === 'news' || tab === 'engine') && (
        <div className="lynx-hub-ops-toolbar">
          <button type="button" className="lynx-app-cta" onClick={handleSave}>
            Сохранить на сервер
          </button>
          {saved ? <span className="lynx-admin-ok">Сохранено</span> : null}
          {saveError ? <span className="lynx-admin-login-error">{saveError}</span> : null}
        </div>
      )}

      {tab === 'status' && <HubOpsStatusPanel isOps={isOps} />}

      {tab === 'news' && (
        <section className="lynx-hub-account-section">
          <div className="lynx-admin-section-head">
            <h2>Новости</h2>
            <button type="button" className="lynx-btn-outline" onClick={addNews}>
              + Запись
            </button>
          </div>
          {content.news.map((post, i) => (
            <article key={post.slug} className="lynx-admin-card">
              <label>
                Заголовок
                <input value={post.title} onChange={(e) => updateNews(i, 'title', e.target.value)} />
              </label>
              <label>
                Дата
                <input value={post.date} onChange={(e) => updateNews(i, 'date', e.target.value)} />
              </label>
              <label>
                Текст
                <textarea value={post.body} rows={3} onChange={(e) => updateNews(i, 'body', e.target.value)} />
              </label>
            </article>
          ))}
        </section>
      )}

      {tab === 'engine' && (
        <section className="lynx-hub-account-section">
          <h2>Ядра движка (витрина Hub)</h2>
          <p className="lynx-lead">
            Политика релизов (manifest, recommended) — в{' '}
            <a href="https://lynx-cloud.ru/admin" target="_blank" rel="noreferrer">
              Lynx Cloud Admin
            </a>
            .
          </p>
          {content.engineCores.map((core, i) => (
            <article key={core.id} className="lynx-admin-card">
              <label>
                Название
                <input value={core.label} onChange={(e) => updateCore(i, 'label', e.target.value)} />
              </label>
              <label>
                Версия
                <input value={core.version} onChange={(e) => updateCore(i, 'version', e.target.value)} />
              </label>
              <label>
                Примечание
                <input value={core.note} onChange={(e) => updateCore(i, 'note', e.target.value)} />
              </label>
            </article>
          ))}
        </section>
      )}

      {tab === 'store' && (
        <section className="lynx-hub-account-section">
          <h2>Каталог магазина (JSON)</h2>
          <p className="lynx-lead">
            Публикуется на lynx-api. Игры Arcade — отдельно, вкладка «Аркада».
          </p>
          <textarea
            className="lynx-admin-json"
            rows={18}
            value={catalogJson}
            onChange={(e) => {
              setCatalogJson(e.target.value);
              setSaved(false);
            }}
          />
          <button type="button" className="lynx-app-cta" style={{ marginTop: 12 }} onClick={handleSaveCatalog}>
            Опубликовать каталог
          </button>
          {saveError && tab === 'store' ? <p className="lynx-admin-login-error">{saveError}</p> : null}
          {saved && tab === 'store' ? <p className="lynx-admin-ok">Сохранено</p> : null}
        </section>
      )}

      {tab === 'arcade' && (
        <section className="lynx-hub-account-section">
          <h2>Публикация в Arcade</h2>
          <p className="lynx-lead">Загрузите готовый <strong>.lynxcart</strong> для Launcher → Аркада → Play.</p>
          <article className="lynx-admin-card">
            <label>
              Название
              <input value={arcadeTitle} onChange={(e) => setArcadeTitle(e.target.value)} placeholder="Lynx Tetris" />
            </label>
            <label>
              ID cart (опционально)
              <input value={arcadeCartId} onChange={(e) => setArcadeCartId(e.target.value)} placeholder="lynx-tetris" />
            </label>
            <label>
              Теги (через запятую)
              <input value={arcadeTags} onChange={(e) => setArcadeTags(e.target.value)} />
            </label>
            <label>
              Файл .lynxcart
              <input ref={cartFileRef} type="file" accept=".lynxcart,application/octet-stream" />
            </label>
            <button type="button" className="lynx-app-cta" onClick={handleUploadCart}>
              Опубликовать
            </button>
            {arcadeMsg ? <p className="lynx-lead">{arcadeMsg}</p> : null}
          </article>
        </section>
      )}

      {tab === 'releases' && (
        <section className="lynx-hub-account-section">
          <h2>Релизы Launcher</h2>
          <p className="lynx-lead">
            Сборка: <code>push-lynx-update-to-server.ps1</code> → <code>/downloads/</code> на Hub.
          </p>
          <ul className="lynx-hub-ops-release-list">
            <li>
              <strong>Windows EXE</strong>
              <span>{LYNX_LAUNCHER_EXE_URL || 'не задан VITE_LYNX_LAUNCHER_EXE_URL'}</span>
            </li>
            <li>
              <strong>Android APK</strong>
              <span>{LYNX_LAUNCHER_APK_URL || 'не задан VITE_LYNX_LAUNCHER_APK_URL'}</span>
            </li>
            <li>
              <strong>Манифест движка</strong>
              <span>{ENGINE_MANIFEST_URL || 'не задан VITE_ENGINE_MANIFEST_URL'}</span>
            </li>
          </ul>
        </section>
      )}
    </div>
  );
}
