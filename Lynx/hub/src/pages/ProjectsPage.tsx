import { Link } from 'react-router-dom';

export function ProjectsPage() {
  return (
    <div className="lynx-page-stack">
      <h1>Маркетплейс</h1>
      <p className="lynx-lead">Ассеты и UI-паки для проектов Lynx — каталог в разработке.</p>
      <Link to="/" className="lynx-app-cta-ghost">
        На главную
      </Link>
    </div>
  );
}
