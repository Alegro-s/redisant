import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
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

type Tab = 'news' | 'engine' | 'store' | 'arcade' | 'releases';

export function AdminPage() {
  const [content, setContent] = useState<HubContent | null>(null);
  const [saved, setSaved] = useState(false);
  const [saveError, setSaveError] = useState('');
  const [tab, setTab] = useState<Tab>('news');
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
    return <p className="lynx-admin-loading">Загрузка…</p>;
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
        setSaveError('Локально сохранено; API отклонил запрос (проверьте VITE_HUB_ADMIN_TOKEN на сервере).');
        setSaved(false);
        return;
      }
    }
    setSaved(true);
  }

  async function handleSaveCatalog() {
    setSaveError('');
    if (hubApiConfigured()) {
      const ok = await saveMarketplaceCatalogToApi(catalogJson);
      if (!ok) {
        setSaveError('Не удалось сохранить каталог на сервере.');
        return;
      }
      setSaved(true);
      return;
    }
    setSaveError('Задайте VITE_HUB_ADMIN_TOKEN для публикации каталога на API.');
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

  return (
    <div className="lynx-admin">
      <header className="lynx-admin-head">
        <h1>Админ-панель Lynx</h1>
        <p>Новости, движок, магазин, аркада и релизы клиента.</p>
        {!hubApiConfigured() ? (
          <p className="lynx-admin-hint">
            Для публикации на сервер задайте <code>VITE_HUB_ADMIN_TOKEN</code> (тот же{' '}
            <code>LYNX_HUB_ADMIN_TOKEN</code> на lynx-api).
          </p>
        ) : null}
        <nav className="lynx-admin-tabs">
          {(
            [
              ['news', 'Новости'],
              ['engine', 'Движок'],
              ['store', 'Магазин'],
              ['arcade', 'Аркада'],
              ['releases', 'Релизы'],
            ] as const
          ).map(([t, label]) => (
            <button
              key={t}
              type="button"
              className={tab === t ? 'lynx-admin-tab is-active' : 'lynx-admin-tab'}
              onClick={() => setTab(t)}
            >
              {label}
            </button>
          ))}
        </nav>
        <div className="lynx-admin-actions">
          {tab !== 'store' && tab !== 'arcade' && tab !== 'releases' ? (
            <button type="button" className="lynx-app-cta" onClick={handleSave}>
              Сохранить
            </button>
          ) : null}
          {saved ? <span className="lynx-admin-ok">Сохранено</span> : null}
          {saveError ? <span className="lynx-admin-login-error">{saveError}</span> : null}
          <Link to="/" className="lynx-link-accent">
            ← На главную
          </Link>
        </div>
      </header>

      {tab === 'news' && (
        <section>
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
        <section>
          <h2>Ядра движка (информация Hub)</h2>
          <p className="lynx-admin-hint">
            Версии для лаунчера и облачных сессий — в{' '}
            <a href="https://metrika-waypoint.ru/dashboard/lynx-cloud/engine" target="_blank" rel="noreferrer">
              Lynx Cloud → Engine
            </a>{' '}
            (манифест <code>/engine/manifest</code>, сессия <code>/me/engine/session</code>).
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
        <section>
          <h2>Каталог магазина (JSON)</h2>
          <p className="lynx-admin-hint">
            Игры с <code>kind: &quot;game&quot;</code> и опубликованные <code>.lynxcart</code> в аркаде — разные
            контуры. Для Play в Launcher используйте вкладку «Аркада».
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
            Опубликовать каталог на API
          </button>
        </section>
      )}

      {tab === 'arcade' && (
        <section>
          <h2>Публикация игры в Arcade</h2>
          <p className="lynx-admin-hint">
            Загрузите готовый <strong>.lynxcart</strong> (упакованный проект с сценой и логикой). Игроки запускают
            его в Launcher → Аркада → Play (тот же runtime, что и Play в редакторе).
          </p>
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
              Опубликовать в Arcade
            </button>
            {arcadeMsg ? <p className="lynx-admin-hint">{arcadeMsg}</p> : null}
          </article>
          <p className="lynx-admin-hint">
            Из редактора: меню проекта → «Выложить cart в Arcade» (нужен <code>cloudPublish.enabled</code> в
            project.json). Или: <code>dart run tool/pack_lynx_cart.dart &lt;project&gt; out.lynxcart</code>
          </p>
        </section>
      )}

      {tab === 'releases' && (
        <section>
          <h2>Релизы Launcher (EXE / APK)</h2>
          <p className="lynx-admin-hint">
            Соберите на ПК скриптом <code>push-lynx-update-to-server.ps1</code> — файлы попадут в{' '}
            <code>/downloads/</code> на Hub.
          </p>
          <ul className="lynx-admin-hint">
            <li>
              Windows EXE: {LYNX_LAUNCHER_EXE_URL || <em>не задан VITE_LYNX_LAUNCHER_EXE_URL</em>}
            </li>
            <li>
              Android APK: {LYNX_LAUNCHER_APK_URL || <em>не задан VITE_LYNX_LAUNCHER_APK_URL</em>}
            </li>
            <li>
              Манифест движка: {ENGINE_MANIFEST_URL || <em>не задан</em>}
            </li>
          </ul>
          <p className="lynx-admin-hint">
            Облачный проект в редакторе: создайте проект в Launcher → облако, откройте в Engine — сессия движка через{' '}
            <code>POST /me/engine/session</code> (Waypoint Lynx Cloud → Engine).
          </p>
        </section>
      )}

    </div>
  );
}
