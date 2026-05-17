/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string;
  readonly VITE_AUTH_URL?: string;
  readonly VITE_WS_URL?: string;
  readonly VITE_AI_SERVICE_URL?: string;
  readonly VITE_PUBLIC_SITE_MODE?: string;
  readonly VITE_LYNX_HUB_URL?: string;
  readonly VITE_LYNX_CLOUD_URL?: string;
  readonly VITE_ROZA_URL?: string;
  readonly VITE_WAYPOINT_DESKTOP_URL?: string;
  readonly VITE_TSPU_SITE_URL?: string;
  readonly VITE_TSPU_APP_URL?: string;
  readonly VITE_ANDROID_APP_URL?: string;
  readonly VITE_IOS_APP_URL?: string;
  readonly PROD: boolean;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
