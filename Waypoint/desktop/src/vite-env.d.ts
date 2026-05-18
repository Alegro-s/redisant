/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_WAYPOINT_CLOUD_URL?: string;
  readonly VITE_WAYPOINT_AUTH_URL?: string;
  readonly VITE_WAYPOINT_API_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
