import { Link } from 'react-router-dom';
import { LYNX_CLOUD_SITE_URL } from '../config/links';

const steps = [
  {
    n: '01',
    title: 'Установите Launcher',
    text: 'Скачайте клиент в разделе «Скачать». Windows или Android — в зависимости от платформы сборки.',
    link: '/download',
    linkLabel: 'Перейти к загрузкам',
  },
  {
    n: '02',
    title: 'Создайте проект',
    text: 'Откройте шаблон или пустую сцену. Редактор, физика и Lua работают в одном окне Launcher.',
  },
  {
    n: '03',
    title: 'Соберите игру',
    text: 'Экспортируйте билд под нужную платформу. Настройки сборки — в клиенте.',
  },
  {
    n: '04',
    title: 'Облако (по желанию)',
    text: 'Синхронизация и кабинет разработчика — в Lynx Cloud после регистрации.',
    external: LYNX_CLOUD_SITE_URL,
    linkLabel: 'Открыть Lynx Cloud',
  },
];

export function DocsPage() {
  return (
    <div className="lynx-docs lynx-docs-simple">
      <header className="lynx-docs-hero">
        <Link to="/" className="lynx-back-link">
          ← Lynx Hub
        </Link>
        <h1>Руководство разработчика</h1>
        <p className="lynx-lead">
          Краткий путь от установки до сборки. Подробные материалы и API — в репозитории проекта и в клиенте.
        </p>
      </header>

      <ol className="lynx-docs-steps">
        {steps.map((s) => (
          <li key={s.n} className="lynx-docs-step">
            <span className="lynx-docs-step-n">{s.n}</span>
            <div>
              <h2>{s.title}</h2>
              <p>{s.text}</p>
              {s.external ? (
                <a href={s.external} target="_blank" rel="noreferrer" className="lynx-card-link">
                  {s.linkLabel} →
                </a>
              ) : s.link ? (
                <Link to={s.link} className="lynx-card-link">
                  {s.linkLabel} →
                </Link>
              ) : null}
            </div>
          </li>
        ))}
      </ol>

      <section className="lynx-docs-more">
        <h2>Что внутри движка</h2>
        <ul>
          <li>2D-рендер, тайлы, UI-слой</li>
          <li>Физика Box2D</li>
          <li>Скрипты Lua и горячая перезагрузка сцен</li>
        </ul>
        <p className="lynx-docs-fine">
          Справочник HTTP API для Cloud — в личном кабинете после входа, не на этой витрине.
        </p>
      </section>
    </div>
  );
}
