/** База auth-api. В dev Vite проксирует `/auth` → :8090 */
export function resolveAuthBase(): string {
  const raw = (import.meta.env.VITE_AUTH_URL as string | undefined)?.trim();
  if (raw) return raw.replace(/\/$/, '');
  if (import.meta.env.DEV) return '/auth';
  return '/auth';
}
