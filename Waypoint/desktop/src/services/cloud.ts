import type { CloudConfig } from './config';

export async function login(cfg: CloudConfig, email: string, password: string) {
  const r = await fetch(`${cfg.authUrl}/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Client-Realm': 'metric' },
    credentials: 'include',
    body: JSON.stringify({ email, password }),
  });
  if (!r.ok) throw new Error(await r.text());
  const data = (await r.json()) as { token?: string };
  return data.token || '';
}

export async function refreshAccess(cfg: CloudConfig): Promise<string> {
  if (!cfg.refreshToken) throw new Error('No refresh token');
  const r = await fetch(`${cfg.authUrl}/auth/token/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh_token: cfg.refreshToken }),
  });
  if (!r.ok) throw new Error('Refresh failed');
  const data = (await r.json()) as { access_token: string };
  return data.access_token;
}

export async function claimPairing(
  cfg: CloudConfig,
  code: string,
  deviceId: string,
  deviceName: string,
) {
  const r = await fetch(`${cfg.authUrl}/auth/desktop/pair/claim`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      code: code.trim().toUpperCase(),
      device_id: deviceId,
      device_name: deviceName,
      host_label: deviceName,
      os_info: navigator.platform,
    }),
  });
  if (!r.ok) throw new Error(await r.text());
  return (await r.json()) as {
    api_key: string;
    access_token: string;
    refresh_token: string;
    cloud_url: string;
  };
}

export async function sendIngest(cfg: CloudConfig, payload: unknown) {
  const base = cfg.apiUrl.replace(/\/$/, '');
  const r = await fetch(`${base}/api/waypoint/ingest`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': cfg.apiKey,
    },
    body: JSON.stringify(payload),
  });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

export async function heartbeat(cfg: CloudConfig) {
  const base = cfg.apiUrl.replace(/\/$/, '');
  await fetch(`${base}/api/waypoint/desktop/heartbeat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-API-Key': cfg.apiKey },
    body: JSON.stringify({ host_label: cfg.deviceName, os_info: navigator.platform }),
  });
}

export function metricOpenUrl(cfg: CloudConfig, path = '/dashboard') {
  const url = `${cfg.cloudUrl.replace(/\/$/, '')}${path}`;
  return url;
}
