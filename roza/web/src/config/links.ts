/** Личный кабинет Roza — свой контур, не Waypoint Metric */
export const ROZA_ACCOUNT_URL = import.meta.env.VITE_ROZA_ACCOUNT_URL ?? '/account';

/** Скачивание десктоп-консультанта (Windows x64) */
export const ROZA_COMPANION_WIN_URL =
  import.meta.env.VITE_ROZA_COMPANION_WIN_URL ?? '/roza/downloads/RozaCompanion-win-x64.exe';

/** Базовый URL API Roza (чат на сайте). Пусто — относительный /api через proxy */
export const ROZA_API_BASE = import.meta.env.VITE_ROZA_API_URL ?? '';

/** Прямая ссылка на ISO RozaOS (S3/CDN). Пусто — кнопка ждёт публикации */
export const ROZAOS_ISO_URL = import.meta.env.VITE_ROZAOS_ISO_URL ?? '';
export const ROZAOS_VERSION = import.meta.env.VITE_ROZAOS_VERSION ?? '0.6.0';

export const ROZA_SECURITY_MSI_URL =
  import.meta.env.VITE_ROZA_SECURITY_MSI_URL ??
  'https://s3.twcstorage.ru/bc39a46d-ee3d-4707-9e3f-9529afb602da/roza-security-updates/msi/RozaSecurity-Setup.msi';
