'use client';

import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { LynxAuthForm } from '@/components/LynxAuthForm';

export default function AdminLoginPage() {
  const router = useRouter();

  return (
    <main className="cloud-apple cloud-cabinet-page">
      <section className="cloud-cabinet-hero">
        <p className="cloud-kicker">Lynx Cloud Admin</p>
        <h1>Операционная панель</h1>
        <p className="cloud-intro-lead">
          Вход через auth-api (роль NEXUS / staff). Управление Engine, проектами и статусом сервисов.
        </p>
        <LynxAuthForm
          onSuccess={() => {
            router.push('/admin/engine');
          }}
        />
        <p className="cloud-cabinet-note">
          <Link href="/">← Витрина</Link>
        </p>
      </section>
    </main>
  );
}
