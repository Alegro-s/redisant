import { resolveLynxAuthBase } from '../utils/authBase';

const TOKEN_KEY = 'lynx_auth_token';
const LOGIN_KEY = 'lynx_auth_login';
const DOWNLOADS_KEY = 'lynx_hub_downloads';

export type LynxProfile = {
  id: string;
  email: string;
  nickname: string;
  role?: string | null;
  realms?: string[];
};

export function getLynxAuthToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function getLynxAuthLogin(): string {
  return localStorage.getItem(LOGIN_KEY) ?? '';
}

export function clearLynxAuth(): void {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(LOGIN_KEY);
}

export function isLynxOps(profile: LynxProfile | null): boolean {
  if (!profile) return false;
  const role = profile.role ?? '';
  return role === 'nexus' || role === 'admin';
}

export async function fetchLynxProfile(): Promise<LynxProfile | null> {
  const token = getLynxAuthToken();
  if (!token) return null;
  const res = await fetch(`${resolveLynxAuthBase()}/profile`, {
    headers: {
      Authorization: `Bearer ${token}`,
      'X-Client-Realm': 'lynx',
    },
    credentials: 'include',
  });
  if (!res.ok) return null;
  return (await res.json()) as LynxProfile;
}

export type HubDownloadRecord = {
  id: string;
  title: string;
  url: string;
  at: string;
};

export function recordHubDownload(item: Omit<HubDownloadRecord, 'at'>): void {
  const prev = listHubDownloads();
  const next: HubDownloadRecord[] = [
    { ...item, at: new Date().toISOString() },
    ...prev.filter((x) => x.id !== item.id),
  ].slice(0, 50);
  localStorage.setItem(DOWNLOADS_KEY, JSON.stringify(next));
}

export function listHubDownloads(): HubDownloadRecord[] {
  try {
    const raw = localStorage.getItem(DOWNLOADS_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as HubDownloadRecord[];
  } catch {
    return [];
  }
}
