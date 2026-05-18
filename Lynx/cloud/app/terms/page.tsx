import Link from 'next/link';
import { lynxTermsSections } from '@/lib/lynxLegal';

export default function TermsPage() {
  return (
    <main className="cloud-legal-page">
      <h1>Условия использования</h1>
      <p className="cloud-legal-lead">Lynx Cloud · экосистема Lynx</p>
      <nav className="cloud-legal-nav">
        <Link href="/privacy">Конфиденциальность</Link>
        <Link href="/terms" className="active">
          Условия
        </Link>
      </nav>
      {lynxTermsSections.map((s) => (
        <section key={s.title}>
          <h2>{s.title}</h2>
          {s.paragraphs.map((p) => (
            <p key={p}>{p}</p>
          ))}
        </section>
      ))}
      <p className="cloud-legal-back">
        <Link href="/">← На главную</Link>
      </p>
    </main>
  );
}
