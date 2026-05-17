export type PublicSiteMode = 'club' | 'metric' | 'console';

const CLUB_HOSTS = new Set(['waypointclub.ru', 'www.waypointclub.ru']);
const METRIC_HOSTS = new Set(['metrika-waypoint.ru', 'www.metrika-waypoint.ru']);

export function resolvePublicSiteMode(hostname = window.location.hostname): PublicSiteMode {
  const host = hostname.toLowerCase();
  if (CLUB_HOSTS.has(host)) return 'club';
  if (METRIC_HOSTS.has(host)) return 'metric';
  return 'console';
}

export function isMarketingHost(hostname = window.location.hostname): boolean {
  const mode = resolvePublicSiteMode(hostname);
  return mode === 'club' || mode === 'metric';
}
