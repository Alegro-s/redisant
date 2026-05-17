/** Личный кабинет Roza — свой контур, не Waypoint Metric */
export const ROZA_ACCOUNT_URL = import.meta.env.VITE_ROZA_ACCOUNT_URL ?? '/account';

/** Скачивание десктоп-консультанта (Windows x64) */
export const ROZA_COMPANION_WIN_URL =
  import.meta.env.VITE_ROZA_COMPANION_WIN_URL ?? '/roza/downloads/RozaCompanion-win-x64.exe';

/** Базовый URL API Roza (чат на сайте). Пусто — относительный /api через proxy */
export const ROZA_API_BASE = import.meta.env.VITE_ROZA_API_URL ?? '';
