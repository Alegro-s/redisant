export type EngineRelease = {
  version: string;
  channel?: string;
  notes?: string;
  sizeBytes?: number;
  artifacts?: Record<string, { url?: string; sha256?: string }>;
};

export type EngineManifest = {
  releases: EngineRelease[];
  recommended_version?: string | null;
  source?: string | null;
};

const CDN_MANIFEST = 'https://lynx-hub.ru/dist/downloads/engine-manifest.json';

export async function fetchEngineManifest(apiUrl?: string): Promise<EngineManifest | null> {
  const urls = [apiUrl, CDN_MANIFEST].filter((u): u is string => Boolean(u?.trim()));
  for (const url of urls) {
    try {
      const res = await fetch(url, { credentials: 'omit' });
      if (!res.ok) continue;
      const data = (await res.json()) as EngineManifest;
      if (data.releases?.length) return data;
    } catch {
      /* try next */
    }
  }
  return null;
}

export function windowsEnginePackUrl(manifest: EngineManifest | null): string | null {
  const rec = manifest?.recommended_version;
  const release =
    manifest?.releases.find((r) => r.version === rec) ?? manifest?.releases[0];
  const art = release?.artifacts?.windows;
  return art?.url?.trim() || null;
}
