import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

type CatalogItem = {
  id: string;
  kind: string;
  title: string;
  author?: string;
  category?: string;
  description?: string;
  version?: string;
  rating?: number;
  tags?: string[];
  builtin?: boolean;
};

type Catalog = {
  items: CatalogItem[];
  updatedAt?: string;
};

const KIND_LABEL: Record<string, string> = {
  plugin: 'Плагин',
  template: 'Шаблон',
  game: 'Игра',
  engine_core: 'Ядро',
};

async function loadCatalog(): Promise<Catalog> {
  try {
    const res = await fetch('/content/marketplace-catalog.json', { cache: 'no-store' });
    if (res.ok) return (await res.json()) as Catalog;
  } catch {
    /* fallback */
  }
  return { items: [] };
}

export function ProjectsPage() {
  const [catalog, setCatalog] = useState<Catalog | null>(null);

  useEffect(() => {
    void loadCatalog().then(setCatalog);
  }, []);

  const items = catalog?.items ?? [];

  return (
    <div className="lynx-page-stack lynx-marketplace-page">
      <h1>Маркетплейс</h1>
      <p className="lynx-lead">
        Плагины, шаблоны и демо-проекты Lynx Engine — те же позиции, что в Launcher и редакторе.
      </p>

      {items.length === 0 ? (
        <p className="lynx-muted">Загрузка каталога…</p>
      ) : (
        <div className="lynx-marketplace-grid">
          {items.map((item) => (
            <article key={item.id} className="lynx-marketplace-card">
              <span className="lynx-marketplace-kind">
                {KIND_LABEL[item.kind] ?? item.kind}
                {item.category ? ` · ${item.category}` : ''}
              </span>
              <h2>{item.title}</h2>
              {item.author ? <p className="lynx-marketplace-author">{item.author}</p> : null}
              <p className="lynx-marketplace-desc">{item.description}</p>
              <div className="lynx-marketplace-meta">
                {item.version ? <span>v{item.version}</span> : null}
                {item.rating != null ? <span>★ {item.rating.toFixed(1)}</span> : null}
                {item.builtin ? <span>Встроенный</span> : null}
              </div>
              {item.tags && item.tags.length > 0 ? (
                <div className="lynx-marketplace-tags">
                  {item.tags.map((t) => (
                    <span key={t}>{t}</span>
                  ))}
                </div>
              ) : null}
            </article>
          ))}
        </div>
      )}

      <p className="lynx-marketplace-foot">
        Открыть в редакторе:{' '}
        <a href="/engine-web/" className="lynx-launch-row-action">
          engine-web →
        </a>
      </p>

      <Link to="/" className="lynx-app-cta-ghost">
        На главную
      </Link>
    </div>
  );
}
