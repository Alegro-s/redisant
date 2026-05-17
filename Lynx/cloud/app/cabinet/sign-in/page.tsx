import Link from 'next/link';
import { LynxAuthForm } from '@/components/LynxAuthForm';
import { LYNX_CABINET_URL } from '@/lib/links';

export default function LynxCabinetSignInPage({
  searchParams,
}: {
  searchParams: { mode?: string };
}) {
  const isRegister = searchParams?.mode === 'register';

  return (
    <main className="cloud-apple cloud-cabinet-page">
      <section className="cloud-cabinet-hero">
        <p className="cloud-kicker">Lynx Cloud</p>
        <h1>{isRegister ? 'Регистрация' : 'Вход'}</h1>
        <p className="cloud-intro-lead">
          Личный кабинет Lynx Cloud — отдельно от Waypoint Metric и Roza AI.
        </p>
        <LynxAuthForm initialRegister={isRegister} />
        <div className="cloud-intro-actions">
          <Link className="cloud-btn-secondary" href={LYNX_CABINET_URL}>
            ← Кабинет Lynx Cloud
          </Link>
          <Link className="cloud-btn-secondary" href="/">
            Витрина
          </Link>
        </div>
      </section>
    </main>
  );
}
