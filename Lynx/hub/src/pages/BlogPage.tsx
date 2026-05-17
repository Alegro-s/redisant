import { useEffect, useState } from 'react';
import type { HubNewsPost } from '../lib/hubContent';
import { loadHubContent } from '../lib/hubContent';

export function BlogPage() {
  const [posts, setPosts] = useState<HubNewsPost[]>([]);

  useEffect(() => {
    loadHubContent().then((c) => setPosts(c.news));
  }, []);

  return (
    <div className="lynx-blog">
      <header className="lynx-page-head lynx-blog-head">
        <p className="lynx-app-section-label" style={{ marginTop: 0 }}>
          Новости
        </p>
        <h1>Релизы и анонсы Lynx</h1>
        <p className="lynx-lead">
          Лента обновляется редакцией Lynx. Уведомления о релизах — в профиле после регистрации.
        </p>
      </header>
      <div className="lynx-blog-list">
        {posts.length === 0 ? (
          <p className="lynx-blog-empty">Новости появятся здесь после публикации. Скоро будет.</p>
        ) : (
          posts.map((p) => (
            <article key={p.slug} className="lynx-blog-post lynx-card-lift">
              <time>{p.date}</time>
              <h2>{p.title}</h2>
              <p>{p.body}</p>
            </article>
          ))
        )}
      </div>
    </div>
  );
}
