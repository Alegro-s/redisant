import Link from 'next/link';
import { lynxPrivacySections } from '@/lib/lynxLegal';

export default function PrivacyPage() {
  return (
    <main className="cloud-legal-page">
      <h1>Политика конфиденциальности</h1>
      <p className="cloud-legal-lead">Lynx Cloud · экосистема Lynx</p>
      <nav className="cloud-legal-nav">
        <Link href="/privacy" className="active">
          Конфиденциальность
        </Link>
        <Link href="/terms">Условия</Link>
      </nav>
      {lynxPrivacySections.map((s) => (
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
