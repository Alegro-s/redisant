import { Link } from 'react-router-dom';
import '../styles/club.css';
import { LINKS } from './links';
import { useDocumentTitle } from '../hooks/useDocumentTitle';

type CatalogItem = {
  name: string;
  desc: string;
  doc: string;
  site?: string;
  internal?: true;
  href?: string;
};

const productCatalog: CatalogItem[] = [
  { name: 'Waypoint Metric', desc: 'Облако: метрики, PostgreSQL, BaaS', doc: '/club/docs/metric', site: LINKS.metric },
  { name: 'Waypoint Desktop', desc: 'Локальное приложение на ПК', doc: '/club/docs/desktop' },
  { name: 'Lynx Hub', desc: 'Скачивание Launcher и документация', doc: '/club/docs/lynx', site: LINKS.lynxHub },
  { name: 'Lynx Cloud', desc: 'Облако для авторов игр', doc: '/club/docs/lynx', site: LINKS.lynxCloud },
  { name: 'Roza AI', desc: 'Консультант Waypoint', doc: '/club/docs/roza-ai', site: `${LINKS.roza}/ai` },
  { name: 'Roza OS', desc: 'Дистрибутив с ассистентом', doc: '/club/docs/roza-os', site: `${LINKS.roza}/os` },
  { name: 'ТГПУ Профиль', desc: 'Кампусное приложение', doc: '/club/docs/tspu', internal: true, href: '/tspu' },
];

const divisions = [
  { n: '01', title: 'Инфраструктура', text: 'Waypoint Metric — облако, ingest, БД и BaaS для приложений.' },
  { n: '02', title: 'Рабочее место', text: 'Waypoint Desktop — Docker и терминал локально, отдельно от облака.' },
  { n: '03', title: 'Игры', text: 'Lynx Hub — клиент и релизы. Lynx Cloud — облако для проектов и сборок.' },
  { n: '04', title: 'ИИ', text: 'Roza — подбренд Waypoint: документы, безопасность ПК и обучение.' },
  { n: '05', title: 'Образование', text: 'ТГПУ Профиль — мобильный кабинет студента.' },
];

const products = [
  {
    span: 'club-span-8',
    tag: 'Облако',
    title: 'Waypoint Metric',
    body: 'Ingest, дашборды, PostgreSQL, REST BaaS. Своя БД в workspace — не Lynx.',
    doc: '/club/docs/metric',
    site: LINKS.metric,
  },
  {
    span: 'club-span-4',
    tag: 'ПК',
    title: 'Waypoint Desktop',
    body: 'Локальный клиент: Docker, терминал, Liza. Не подменяет Metric.',
    doc: '/club/docs/desktop',
  },
  {
    span: 'club-span-4',
    tag: 'Hub',
    title: 'Lynx Hub',
    body: 'Скачивание Launcher, новости и документация движка.',
    doc: '/club/docs/lynx',
    site: LINKS.lynxHub,
  },
  {
    span: 'club-span-4',
    tag: 'Облако',
    title: 'Lynx Cloud',
    body: 'Витрина облака для авторов. Проекты и сборки — в кабинете после входа.',
    doc: '/club/docs/lynx',
    site: LINKS.lynxCloud,
  },
  {
    span: 'club-span-4',
    tag: 'ИИ',
    title: 'Roza AI',
    body: 'Консультант Waypoint: документы, ПК, обучение. Чат и приложение.',
    doc: '/club/docs/roza-ai',
    site: `${LINKS.roza}/ai`,
  },
  {
    span: 'club-span-4',
    tag: 'ОС',
    title: 'Roza OS',
    body: 'Дистрибутив с ассистентом в системе.',
    doc: '/club/docs/roza-os',
    site: `${LINKS.roza}/os`,
    soon: true,
  },
  {
    span: 'club-span-6',
    tag: 'Кампус',
    title: 'ТГПУ Профиль',
    body: 'Расписание, оценки, Moodle для ТГПУ.',
    doc: '/club/docs/tspu',
    internal: true as const,
    href: '/tspu',
  },
];

function catalogHref(item: CatalogItem): string {
  if (item.internal && item.href) return item.href;
  if (item.site) return item.site;
  return item.doc;
}

function isExternalCatalog(item: CatalogItem): boolean {
  return Boolean(item.site);
}

export function WaypointClubPage() {
  useDocumentTitle('Waypoint Club — экосистема Waypoint');
  return (
    <div className="club-root">
      <nav className="club-nav">
        <Link to="/" className="club-logo">
          Waypoint <em>Club</em>
        </Link>
        <div className="club-nav-links">
          <div className="club-dropdown-wrap">
            <span className="club-dropdown-trigger">Решения</span>
            <div className="club-dropdown" role="menu">
              {productCatalog.map((item) =>
                isExternalCatalog(item) ? (
                  <a
                    key={item.name}
                    href={catalogHref(item)}
                    className="club-catalog-item"
                    role="menuitem"
                    target="_blank"
                    rel="noreferrer"
                  >
                    <span className="club-catalog-name">{item.name}</span>
                    <span className="club-catalog-desc">{item.desc}</span>
                  </a>
                ) : item.internal && item.href ? (
                  <Link key={item.name} to={item.href} className="club-catalog-item" role="menuitem">
                    <span className="club-catalog-name">{item.name}</span>
                    <span className="club-catalog-desc">{item.desc}</span>
                  </Link>
                ) : (
                  <Link key={item.name} to={item.doc} className="club-catalog-item" role="menuitem">
                    <span className="club-catalog-name">{item.name}</span>
                    <span className="club-catalog-desc">{item.desc}</span>
                  </Link>
                ),
              )}
            </div>
          </div>
          <a href="#products">Продукты</a>
          <a href="#docs">Документация</a>
        </div>
      </nav>

      <main className="club-main">
        <section className="club-hero" style={{ position: 'relative' }}>
          <div className="club-hero-orbit" aria-hidden>
            <span />
            <span />
            <span />
          </div>
          <p className="club-hero-tag">Экосистема Waypoint</p>
          <h1>
            Сногсшибательные
            <span className="line2">инструменты под одним зонтиком</span>
          </h1>
          <p className="club-hero-lead">
            Инфраструктура, разработка, ИИ и образование — в меню «Решения» переход на сайты продуктов, документация — на
            Club.
          </p>
        </section>

        <p className="club-section-label" id="divisions">
          Направления
        </p>
        <div className="club-divisions">
          {divisions.map((d) => (
            <article key={d.n} className="club-division">
              <div className="club-division-num">{d.n}</div>
              <h3>{d.title}</h3>
              <p>{d.text}</p>
            </article>
          ))}
        </div>

        <p className="club-section-label" id="products">
          Продукты
        </p>
        <div className="club-bento">
          {products.map((p) => {
            const cls = `club-bento-card ${p.span}${'soon' in p && p.soon ? ' tag-soon' : ''}`;
            const inner = (
              <>
                <span className="tag">{p.tag}</span>
                <h3>{p.title}</h3>
                <p>{p.body}</p>
                <span className="club-bento-doc-hint">
                  {'site' in p && p.site ? 'Открыть сайт →' : 'Документация на Club →'}
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
              return (
                <a key={p.title} href={p.site} className={cls} target="_blank" rel="noreferrer">
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

        <p className="club-section-label" id="docs">
          Документация на Club
        </p>
        <p className="club-docs-lead">Обзор каждого продукта здесь. Сайты и кабинеты — по ссылкам в меню «Решения».</p>
        <div className="club-docs">
          {productCatalog.map((item) =>
            isExternalCatalog(item) ? (
              <a key={item.name} href={catalogHref(item)} className="club-doc-link" target="_blank" rel="noreferrer">
                <strong>{item.name}</strong>
                {item.desc}
              </a>
            ) : (
              <Link
                key={item.name}
                to={item.internal && item.href ? item.href : item.doc}
                className="club-doc-link"
              >
                <strong>{item.name}</strong>
                {item.desc}
              </Link>
            ),
          )}
        </div>
      </main>

      <footer className="club-footer">© Waypoint Club</footer>
    </div>
  );
}
