import { resolveLynxApiBase } from './config';

export function getLynxAuthToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('lynx_auth_token');
}

export function lynxApiBase(): string {
  return resolveLynxApiBase().replace(/\/$/, '');
}

export async function lynxAdminFetch<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const token = getLynxAuthToken();
  if (!token) throw new Error('Требуется вход (роль staff/nexus).');
  const url = `${lynxApiBase()}${path.startsWith('/') ? path : `/${path}`}`;
  const res = await fetch(url, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      ...(init.headers as Record<string, string> | undefined),
    },
    credentials: 'include',
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `HTTP ${res.status}`);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

export async function checkServiceHealth(url: string): Promise<boolean> {
  try {
    const res = await fetch(url, { method: 'GET', cache: 'no-store' });
    return res.ok;
  } catch {
    return false;
  }
}
