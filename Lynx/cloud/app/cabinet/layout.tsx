import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Кабинет — Lynx Cloud',
  description: 'Личный кабинет Lynx Cloud: проекты, сборки и ключи API.',
};

export default function CabinetLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
