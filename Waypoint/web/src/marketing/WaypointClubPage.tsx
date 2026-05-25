import { Link } from 'react-router-dom';
import '../styles/club.css';
import { LINKS, productSiteUrl, desktopDocsUrl, clubPath, isExternalUrl } from './links';
import { useDocumentTitle } from '../hooks/useDocumentTitle';

type CatalogItem = {
  name: string;
  desc: string;
  doc: string;
  productDocs?: string;
  site?: string;
  siteHash?: string;
  internal?: true;
  href?: string;
};

const productCatalog: CatalogItem[] = [
  { name: 'Waypoint Metric', desc: 'Облако: метрики, PostgreSQL, BaaS', doc: '/club/docs/metric', site: LINKS.metric, siteHash: '#modules' },
  { name: 'Waypoint Desktop', desc: 'Локальное приложение на ПК', doc: '/club/docs/desktop', productDocs: desktopDocsUrl(), site: LINKS.desktop },
  { name: 'Lynx Hub', desc: 'Launcher и документация движка', doc: '/club/docs/lynx', site: LINKS.lynxHub },
  { name: 'Lynx Cloud', desc: 'Облако для авторов игр', doc: '/club/docs/lynx', site: LINKS.lynxCloud },
  { name: 'Roza AI', desc: 'Чат и консультант', doc: '/club/docs/roza-ai', site: '/roza/ai' },
  { name: 'Roza OS', desc: 'Дистрибутив с Liza', doc: '/club/docs/roza-os', site: '/roza/os' },
  { name: 'Roza Security', desc: 'Защита Windows и Roza OS', doc: '/club/docs/roza-os', site: '/roza/security' },
  { name: 'ТГПУ Профиль', desc: 'Кампусное приложение', doc: '/club/docs/tspu', internal: true, href: '/tspu' },
];

const flow = [
  { n: '01', label: 'Metric', sub: 'Облако, ingest, PostgreSQL' },
  { n: '02', label: 'Desktop', sub: 'Docker и терминал на ПК' },
  { n: '03', label: 'Lynx', sub: 'Движок и облако авторов' },
  { n: '04', label: 'Roza', sub: 'ИИ, ОС и Security' },
];

const products = [
  { tag: 'Облако', title: 'Waypoint Metric', body: 'Ingest, дашборды, PostgreSQL и REST BaaS.', doc: '/club/docs/metric', site: productSiteUrl(LINKS.metric, '#modules') },
  { tag: 'ПК', title: 'Waypoint Desktop', body: 'Docker, терминал и Liza локально.', doc: '/club/docs/desktop', site: LINKS.desktop },
  { tag: 'Hub', title: 'Lynx Hub', body: 'Скачивание Launcher и документация.', doc: '/club/docs/lynx', site: LINKS.lynxHub },
  { tag: 'Облако', title: 'Lynx Cloud', body: 'Проекты и сборки в кабинете.', doc: '/club/docs/lynx', site: LINKS.lynxCloud },
  { tag: 'ИИ', title: 'Roza AI', body: 'Чат: документы, ПК, обучение.', doc: '/club/docs/roza-ai', site: '/roza/ai' },
  { tag: 'ОС', title: 'Roza OS', body: 'Дистрибутив с ассистентом.', doc: '/club/docs/roza-os', site: '/roza/os' },
  { tag: 'Защита', title: 'Roza Security', body: 'Агент Windows и Roza OS.', doc: '/club/docs/roza-os', site: '/roza/security' },
  { tag: 'Кампус', title: 'ТГПУ Профиль', body: 'Расписание и Moodle.', doc: '/club/docs/tspu', internal: true as const, href: '/tspu' },
];

function catalogHref(item: CatalogItem): string {
  if (item.internal && item.href) return item.href;
  if (item.site?.startsWith('/')) return item.site;
  if (item.site) return productSiteUrl(item.site, item.siteHash);
  return item.doc;
}

export function WaypointClubPage() {
  useDocumentTitle('Waypoint Club — экосистема Waypoint');
  return (
    <div className="club-root">
      <header className="club-nav">
        <Link to="/" className="club-logo">
          Waypoint <em>Club</em>
        </Link>
        <nav className="club-nav-links" aria-label="Навигация">
          <div className="club-dropdown-wrap">
            <span className="club-dropdown-trigger">Решения</span>
            <div className="club-dropdown" role="menu">
              {productCatalog.map((item) =>
                item.internal && item.href ? (
                  <Link key={item.name} to={item.href} className="club-catalog-item" role="menuitem">
                    <span className="club-catalog-name">{item.name}</span>
                    <span className="club-catalog-desc">{item.desc}</span>
                  </Link>
                ) : (
                  <a
                    key={item.name}
                    href={catalogHref(item)}
                    className="club-catalog-item"
                    role="menuitem"
                    target={item.internal ? undefined : '_blank'}
                    rel={item.internal ? undefined : 'noreferrer'}
                  >
                    <span className="club-catalog-name">{item.name}</span>
                    <span className="club-catalog-desc">{item.desc}</span>
                  </a>
                ),
              )}
            </div>
          </div>
          <a href="#flow">Серия</a>
          <a href="#products">Продукты</a>
          <a href="#docs">Документация</a>
        </nav>
      </header>

      <main className="club-main">
        <section className="club-hero club-reveal">
          <p className="club-hero-tag">Waypoint Club</p>
          <h1>
            Экосистема Waypoint
            <span className="line2">для облака, игр и ИИ</span>
          </h1>
          <p className="club-hero-lead">
            Каталог продуктов серии: Metric, Desktop, Lynx, Roza и кампусные сервисы. Сайты и кабинеты — из меню
            «Решения».
          </p>
          <div className="club-hero-actions">
            <a href="#products" className="club-btn club-btn-primary">
              Продукты
            </a>
            <a href="#docs" className="club-btn club-btn-ghost">
              Документация
            </a>
          </div>
          <div className="club-hero-beam" aria-hidden />
        </section>

        <p className="club-section-title club-reveal" id="flow">
          Серия Waypoint
        </p>
        <div className="club-flow club-reveal">
          {flow.map((s) => (
            <article key={s.n} className="club-flow-card">
              <span className="club-flow-num">{s.n}</span>
              <strong>{s.label}</strong>
              <span>{s.sub}</span>
            </article>
          ))}
        </div>

        <p className="club-section-title club-reveal" id="products">
          Продукты
        </p>
        <div className="club-products-grid club-reveal">
          {products.map((p) => {
            const cls = 'club-product-card';
            const inner = (
              <>
                <span className="tag">{p.tag}</span>
                <h3>{p.title}</h3>
                <p>{p.body}</p>
                <span className="club-product-link">
                  {'site' in p && p.site ? 'Открыть →' : 'internal' in p && p.internal ? 'Открыть →' : 'Обзор →'}
                </span>
              </>
            );
            if ('internal' in p && p.internal && 'href' in p) {
              return (
                <Link key={p.title} to={p.href} className={cls}>
                  {inner}
                </Link>
              );
            }
            if ('site' in p && p.site) {
              const ext = isExternalUrl(p.site);
              return (
                <a key={p.title} href={p.site} className={cls} target={ext ? '_blank' : undefined} rel={ext ? 'noreferrer' : undefined}>
                  {inner}
                </a>
              );
            }
            return (
              <Link key={p.title} to={p.doc} className={cls}>
                {inner}
              </Link>
            );
          })}
        </div>

        <p className="club-section-title club-reveal" id="docs">
          Документация
        </p>
        <p className="club-docs-lead club-reveal">Обзоры на Club — в том же формате, что и документация Desktop.</p>
        <div className="club-docs-grid club-reveal">
          {productCatalog.map((item) =>
            item.internal && item.href ? (
              <Link key={item.name} to={item.doc} className="club-doc-tile">
                <h3>{item.name}</h3>
                <p>{item.desc}</p>
              </Link>
            ) : (
              <Link key={item.name} to={item.doc} className="club-doc-tile">
                <h3>{item.name}</h3>
                <p>{item.desc}</p>
              </Link>
            ),
          )}
        </div>

        <section className="club-cta-band club-reveal">
          <div>
            <h2>Начните с Metric или Desktop</h2>
            <p>Облако и локальное рабочее место — точки входа в серию Waypoint.</p>
          </div>
          <a className="club-btn club-btn-primary" href={LINKS.metric}>
            Waypoint Metric →
          </a>
        </section>
      </main>

      <footer className="club-footer">© Waypoint Club</footer>
    </div>
  );
}
