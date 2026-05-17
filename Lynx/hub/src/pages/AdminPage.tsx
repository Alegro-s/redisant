import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import type { HubContent } from '../lib/hubContent';
import { loadHubContent, saveHubContentOverride } from '../lib/hubContent';

export function AdminPage() {
  const [content, setContent] = useState<HubContent | null>(null);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    loadHubContent().then(setContent);
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

  function handleSave() {
    if (!content) return;
    saveHubContentOverride(content);
    setSaved(true);
  }

  return (
    <div className="lynx-admin">
      <header className="lynx-admin-head">
        <h1>Админ-панель Hub</h1>
        <p>Новости и версии ядра. Сохранение — в localStorage (для продакшена подключите API).</p>
        <div className="lynx-admin-actions">
          <button type="button" className="lynx-app-cta" onClick={handleSave}>
            Сохранить
          </button>
          {saved ? <span className="lynx-admin-ok">Сохранено</span> : null}
          <Link to="/" className="lynx-link-accent">
            ← На главную
          </Link>
        </div>
      </header>

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

      <section>
        <h2>Ядра движка</h2>
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
    </div>
  );
}
