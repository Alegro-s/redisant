'use client';

import { usePathname } from 'next/navigation';
import { CloudSiteHeader } from '@/components/CloudSiteHeader';
import { SiteFooter } from '@/components/SiteFooter';

/** Скрывает витринный header/footer на /admin (свой layout). */
export function CloudChrome({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const bare = pathname?.startsWith('/admin');

  if (bare) {
    return <>{children}</>;
  }

  return (
    <>
      <CloudSiteHeader />
      <div className="shell cloud-shell">{children}</div>
      <SiteFooter />
    </>
  );
}
