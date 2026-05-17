import { resolvePublicSiteMode } from './siteMode';
import { WaypointClubPage } from './WaypointClubPage';
import { MetricLandingPage } from './MetricLandingPage';

/** Публичная витрина по hostname или VITE_PUBLIC_SITE_MODE (club | metric). */
export function PublicLanding() {
  const override = (import.meta.env.VITE_PUBLIC_SITE_MODE as string | undefined)?.trim().toLowerCase();
  const mode =
    override === 'club' || override === 'metric' ? override : resolvePublicSiteMode();

  if (mode === 'club') return <WaypointClubPage />;
  if (mode === 'metric') return <MetricLandingPage />;
  // localhost:3000 — витрина Waypoint Club, не Metric
  const host = typeof window !== 'undefined' ? window.location.hostname : '';
  if (host === 'localhost' || host === '127.0.0.1') return <WaypointClubPage />;
  return <MetricLandingPage />;
}
