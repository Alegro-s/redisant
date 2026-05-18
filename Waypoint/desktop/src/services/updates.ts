import type { CloudConfig } from './config';

export type ReleaseManifest = {
  latest: string;
  channel: string;
  downloads?: { windows?: { url: string } };
};

export async function checkForUpdate(cfg: CloudConfig, currentVersion: string) {
  const base = cfg.cloudUrl.replace(/\/$/, '');
  const r = await fetch(`${base}/desktop-releases.json`, { cache: 'no-store' });
  if (!r.ok) return null;
  const m = (await r.json()) as ReleaseManifest;
  if (m.latest && m.latest !== currentVersion) {
    return { version: m.latest, url: m.downloads?.windows?.url || `${base}/desktop/releases` };
  }
  return null;
}
