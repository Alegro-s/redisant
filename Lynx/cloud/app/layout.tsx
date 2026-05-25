import type { Metadata } from 'next';
import './globals.css';
import { SiteFooter } from '@/components/SiteFooter';
import { CloudSiteHeader } from '@/components/CloudSiteHeader';

export const metadata: Metadata = {
  title: 'Lynx Cloud — облако для разработчиков',
  description: 'Знакомство с Lynx Cloud. Проекты, сборки и аналитика — в личном кабинете после входа.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ru">
      <body className="lynx-cloud-site">
        <CloudSiteHeader />
        <div className="shell cloud-shell">{children}</div>
        <SiteFooter />
      </body>
    </html>
  );
}
