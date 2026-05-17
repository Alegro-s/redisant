/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_LYNX_CLOUD_URL?: string;
  readonly VITE_WAYPOINT_CONSOLE_URL?: string;
  readonly VITE_WAYPOINT_CLUB_URL?: string;
  readonly VITE_WAYPOINT_METRIC_URL?: string;
  readonly VITE_ENGINE_MANIFEST_URL?: string;
  readonly VITE_LYNX_LAUNCHER_EXE_URL?: string;
  readonly VITE_LYNX_LAUNCHER_APK_URL?: string;
  readonly VITE_LYNX_SOURCES_ZIP_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
