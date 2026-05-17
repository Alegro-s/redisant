import { resolveApiBase } from './apiBase';

/** База auth-api. В dev через Vite proxy `/auth` → :8090 (один origin для cookie). */
export function resolveAuthBase(): string {
  const raw = (import.meta.env.VITE_AUTH_URL as string | undefined)?.trim();
  if (raw) {
    return raw.replace(/\/$/, '');
  }
  return resolveApiBase();
}
