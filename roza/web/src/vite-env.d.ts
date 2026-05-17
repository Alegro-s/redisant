/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_ROZA_URL?: string;
  readonly VITE_ROZA_ACCOUNT_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
