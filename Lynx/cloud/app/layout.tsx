import type { Metadata } from 'next';
import './globals.css';
import { CloudChrome } from '@/components/CloudChrome';

export const metadata: Metadata = {
  title: 'Lynx Cloud — облако для разработчиков',
  description: 'Знакомство с Lynx Cloud. Проекты, сборки и аналитика — в личном кабинете после входа.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ru" className="cloud-light">
      <body className="lynx-cloud-site cloud-light">
        <CloudChrome>{children}</CloudChrome>
      </body>
    </html>
  );
}
