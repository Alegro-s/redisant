import { resolveLynxApiBase } from './config';
import { resolveLynxAuthBase } from './authBase';

export function getLynxAuthToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('lynx_auth_token');
}

export function getLynxAuthLogin(): string {
  if (typeof window === 'undefined') return '';
  return localStorage.getItem('lynx_auth_login') ?? '';
}

export type LynxProfile = {
  email: string;
  nickname: string;
  role?: string | null;
};

export function lynxApiBase(): string {
  return resolveLynxApiBase().replace(/\/$/, '');
}

export function lynxAuthBase(): string {
  return resolveLynxAuthBase().replace(/\/$/, '');
}

export function isLynxOps(profile: LynxProfile | null): boolean {
  if (!profile) return false;
  const role = profile.role ?? '';
  return role === 'nexus' || role === 'admin';
}

export async function fetchLynxProfile(): Promise<LynxProfile | null> {
  const token = getLynxAuthToken();
  if (!token) return null;
  const res = await fetch(`${lynxAuthBase()}/profile`, {
    headers: {
      Authorization: `Bearer ${token}`,
      'X-Client-Realm': 'lynx',
    },
    credentials: 'include',
  });
  if (!res.ok) return null;
  return (await res.json()) as LynxProfile;
}

export async function lynxCabinetFetch<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const token = getLynxAuthToken();
  if (!token) throw new Error('Требуется вход.');
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

export async function lynxAdminFetch<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  return lynxCabinetFetch<T>(path, init);
}

export async function checkServiceHealth(url: string): Promise<boolean> {
  try {
    const res = await fetch(url, { method: 'GET', cache: 'no-store' });
    return res.ok;
  } catch {
    return false;
  }
}
