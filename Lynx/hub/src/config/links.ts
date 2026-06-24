

/** Витрина Lynx Cloud (не Yandex Cloud). */
export const LYNX_CLOUD_SITE_URL =
  import.meta.env.VITE_LYNX_CLOUD_URL?.trim() || 'https://lynx-cloud.ru';

export const ROZA_SITE_URL = import.meta.env.VITE_ROZA_URL ?? 'https://waypointclub.ru/roza';

/** Кабинет Lynx Cloud — не Waypoint Metric */
export const LYNX_CABINET_URL =
  import.meta.env.VITE_LYNX_CABINET_URL ?? 'https://lynx-cloud.ru/cabinet';

export const WAYPOINT_CLUB_URL = import.meta.env.VITE_WAYPOINT_CLUB_URL ?? 'https://waypointclub.ru';

export const WAYPOINT_METRIC_URL = import.meta.env.VITE_WAYPOINT_METRIC_URL ?? 'https://metrika-waypoint.ru';

export const ENGINE_MANIFEST_URL = import.meta.env.VITE_ENGINE_MANIFEST_URL ?? '';

/** CDN fallback when API manifest is empty or unavailable. */
export const ENGINE_MANIFEST_CDN_URL =
  import.meta.env.VITE_ENGINE_MANIFEST_CDN_URL?.trim() ||
  'https://lynx-hub.ru/dist/downloads/engine-manifest.json';

/** Flutter Web editor (hosted on Hub static). */
export const ENGINE_WEB_BASE = import.meta.env.VITE_ENGINE_WEB_BASE?.trim() || '/engine-web';

export const ENGINE_WEB_DEMO_URL = `${ENGINE_WEB_BASE}/index.html`;


export const LYNX_LAUNCHER_EXE_URL = import.meta.env.VITE_LYNX_LAUNCHER_EXE_URL ?? '';

export const LYNX_LAUNCHER_APK_URL = import.meta.env.VITE_LYNX_LAUNCHER_APK_URL ?? '';


export const LYNX_SOURCES_ZIP_URL = import.meta.env.VITE_LYNX_SOURCES_ZIP_URL ?? '';
