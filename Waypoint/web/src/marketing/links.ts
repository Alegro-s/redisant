export const LINKS = {
  club: import.meta.env.VITE_CLUB_URL ?? 'https://waypointclub.ru',
  metric: import.meta.env.VITE_METRIC_URL ?? 'https://metrika-waypoint.ru',
  lynxHub: import.meta.env.VITE_LYNX_HUB_URL ?? 'https://lynx-hub.ru',
  lynxCloud: import.meta.env.VITE_LYNX_CLOUD_URL ?? 'https://lynx-cloud.ru',
  /** Подбренд Waypoint, путь на Club — без отдельного домена */
  roza: import.meta.env.VITE_ROZA_URL ?? 'https://waypointclub.ru/roza',
  desktopDownload: import.meta.env.VITE_WAYPOINT_DESKTOP_URL ?? '',
  tspuSite: import.meta.env.VITE_TSPU_SITE_URL ?? 'https://tsput.ru',
  tspuApp: import.meta.env.VITE_TSPU_APP_URL ?? '',
  university: 'https://tsput.ru',
} as const;
