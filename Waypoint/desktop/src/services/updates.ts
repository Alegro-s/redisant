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
    const fallback =
      "https://s3.twcstorage.ru/bc39a46d-ee3d-4707-9e3f-9529afb602da/project's/waypointdesktop/Waypoint_0.1.0_x64_en-US.msi";
    return { version: m.latest, url: m.downloads?.windows?.url || fallback };
  }
  return null;
}
