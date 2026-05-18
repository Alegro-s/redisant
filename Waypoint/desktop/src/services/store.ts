import { load } from '@tauri-apps/plugin-store';
import type { CloudConfig } from './config';
import { defaultConfig } from './config';

const STORE_PATH = 'settings.json';

export async function loadConfig(): Promise<CloudConfig> {
  const store = await load(STORE_PATH, { defaults: {}, autoSave: true });
  const base = defaultConfig();
  const keys = Object.keys(base) as (keyof CloudConfig)[];
  const out: CloudConfig = { ...base };
  for (const k of keys) {
    const v = await store.get<string>(k);
    if (v !== undefined && v !== null) {
      (out as Record<string, unknown>)[k] = v;
    }
  }
  return out;
}

export async function saveConfig(cfg: CloudConfig): Promise<void> {
  const store = await load(STORE_PATH, { defaults: {}, autoSave: true });
  for (const [k, v] of Object.entries(cfg)) {
    await store.set(k, v);
  }
  await store.save();
}

export async function loadSecure(key: string): Promise<string> {
  try {
    const { invoke } = await import('@tauri-apps/api/core');
    return (await invoke<string>('secure_get', { key })) || '';
  } catch {
    return '';
  }
}

export async function saveSecure(key: string, value: string): Promise<void> {
  const { invoke } = await import('@tauri-apps/api/core');
  await invoke('secure_set', { key, value });
}
