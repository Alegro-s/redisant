/** Auth API: в проде — `/auth` на текущем домене (lynx-cloud.ru или lynx-hub.ru). */
export function resolveLynxAuthBase(): string {
  const raw = process.env.NEXT_PUBLIC_LYNX_AUTH_URL?.trim();
  if (raw) return raw.replace(/\/$/, '');
  if (typeof window !== 'undefined') {
    return `${window.location.origin}/auth`;
  }
  return '/auth';
}
