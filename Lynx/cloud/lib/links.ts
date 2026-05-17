/** Личный кабинет Lynx Cloud — только Lynx, не Waypoint Metric */
export const LYNX_CABINET_URL =
  process.env.NEXT_PUBLIC_LYNX_CABINET_URL ?? 'https://lynx-cloud.ru/cabinet';

export const LYNX_HUB_URL = process.env.NEXT_PUBLIC_LYNX_HUB_URL ?? 'https://lynx-hub.ru';

/** @deprecated Используйте LYNX_CABINET_URL */
export const DEVELOPER_CONSOLE_URL = LYNX_CABINET_URL;

export const WAYPOINT_CONSOLE_URL = LYNX_CABINET_URL;
