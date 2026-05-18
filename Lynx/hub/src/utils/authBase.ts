/** Auth API: в проде — тот же домен `/auth` (nginx → auth-api). */
export function resolveLynxAuthBase(): string {
  const raw = (import.meta.env.VITE_LYNX_AUTH_URL as string | undefined)?.trim();
  if (raw) return raw.replace(/\/$/, '');
  if (import.meta.env.DEV) return '/auth';
  if (typeof window !== 'undefined') {
    return `${window.location.origin}/auth`;
  }
  return '/auth';
}
