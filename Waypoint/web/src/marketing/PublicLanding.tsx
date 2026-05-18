import { resolvePublicSiteMode } from './siteMode';
import { WaypointClubPage } from './WaypointClubPage';
import { MetricCloudLandingPage } from './MetricCloudLandingPage';

/** Club — главный сайт; Metric — облако. Desktop — маршруты /desktop/* на домене Metric. */
export function PublicLanding() {
  const raw = (import.meta.env.VITE_PUBLIC_SITE_MODE as string | undefined)?.trim().toLowerCase();
  const override = raw === 'club' || raw === 'metric' ? raw : undefined;
  const mode = override ?? resolvePublicSiteMode();

  if (mode === 'club') return <WaypointClubPage />;
  if (mode === 'metric') return <MetricCloudLandingPage />;

  const host = typeof window !== 'undefined' ? window.location.hostname : '';
  if (host === 'localhost' || host === '127.0.0.1') return <WaypointClubPage />;
  return <MetricCloudLandingPage />;
}
