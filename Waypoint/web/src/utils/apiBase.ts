
export function resolveApiBase(): string {
  const raw = (import.meta.env.VITE_API_URL as string | undefined)?.trim();

  if (typeof window !== 'undefined') {
    const h = window.location.hostname;
    if (h && h !== 'localhost' && h !== '127.0.0.1' && h !== '[::1]') {
      if (!raw || /localhost|127\.0\.0\.1/i.test(raw)) {
        return '/api';
      }
      return raw.replace(/\/$/, '');
    }
  }

  if (import.meta.env.PROD) {
    if (!raw || /localhost|127\.0\.0\.1/i.test(raw)) {
      return '/api';
    }
    return raw.replace(/\/$/, '');
  }
  if (raw && raw.length > 0) {
    return raw.replace(/\/$/, '');
  }
  return '/api';
}
