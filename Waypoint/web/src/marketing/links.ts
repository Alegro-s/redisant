const metricOrigin = () =>
  (import.meta.env.VITE_METRIC_URL ?? 'https://metrika-waypoint.ru').replace(/\/$/, '');

const clubOrigin = () =>
  (import.meta.env.VITE_CLUB_URL ?? 'https://waypointclub.ru').replace(/\/$/, '');

/** Публичная ссылка на установщик (Timeweb S3) */
export const DESKTOP_INSTALLER_URL =
  import.meta.env.VITE_WAYPOINT_DESKTOP_URL ??
  "https://s3.twcstorage.ru/bc39a46d-ee3d-4707-9e3f-9529afb602da/project's/waypointdesktop/WaypointDesktop-setup.msi";

export const LINKS = {
  club: clubOrigin(),
  metric: metricOrigin(),
  /** Подраздел облака Metric (без отдельного домена), как /roza на Club */
  desktop: `${metricOrigin()}/desktop`,
  lynxHub: import.meta.env.VITE_LYNX_HUB_URL ?? 'https://lynx-hub.ru',
  lynxCloud: import.meta.env.VITE_LYNX_CLOUD_URL ?? 'https://lynx-cloud.ru',
  roza: (import.meta.env.VITE_ROZA_URL ?? `${clubOrigin()}/roza`).replace(/\/?$/, ''),
  desktopDownload: DESKTOP_INSTALLER_URL,
  tspuSite: import.meta.env.VITE_TSPU_SITE_URL ?? 'https://tsput.ru',
  tspuApp: import.meta.env.VITE_TSPU_APP_URL ?? '',
  university: 'https://tsput.ru',
} as const;

export function productSiteUrl(base: string, hash?: string): string {
  const url = base.replace(/\/$/, '');
  return hash ? `${url}${hash.startsWith('#') ? hash : `#${hash}`}` : url;
}

/** Документация Desktop на домене Metric */
export function desktopDocsUrl(topic?: string): string {
  const base = metricOrigin();
  if (!topic || topic === 'start') return `${base}/desktop/docs`;
  return `${base}/desktop/docs/${topic.replace(/^\//, '')}`;
}
