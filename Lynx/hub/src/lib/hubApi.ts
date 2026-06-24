const API_BASE = (import.meta.env.VITE_LYNX_API_BASE ?? '/lynx').replace(/\/$/, '');

const ADMIN_TOKEN = import.meta.env.VITE_HUB_ADMIN_TOKEN ?? '';

function authHeaders(): HeadersInit {
  const h: Record<string, string> = { 'Content-Type': 'application/json' };
  const bearer = localStorage.getItem('lynx_auth_token');
  if (bearer) h.Authorization = `Bearer ${bearer}`;
  if (ADMIN_TOKEN) h['X-Lynx-Hub-Admin-Token'] = ADMIN_TOKEN;
  return h;
}

function uploadHeaders(): HeadersInit {
  const h: Record<string, string> = {};
  const bearer = localStorage.getItem('lynx_auth_token');
  if (bearer) h.Authorization = `Bearer ${bearer}`;
  if (ADMIN_TOKEN) h['X-Lynx-Hub-Admin-Token'] = ADMIN_TOKEN;
  return h;
}

export function hubApiConfigured(): boolean {
  return Boolean(ADMIN_TOKEN) || Boolean(localStorage.getItem('lynx_auth_token'));
}

export async function fetchHubContentFromApi(): Promise<import('./hubContent').HubContent | null> {
  try {
    const res = await fetch(`${API_BASE}/v1/hub/content`);
    if (!res.ok) return null;
    return (await res.json()) as import('./hubContent').HubContent;
  } catch {
    return null;
  }
}

export async function saveHubContentToApi(content: import('./hubContent').HubContent): Promise<boolean> {
  if (!hubApiConfigured()) return false;
  const res = await fetch(`${API_BASE}/v1/hub/content`, {
    method: 'PUT',
    headers: authHeaders(),
    body: JSON.stringify(content),
  });
  return res.ok || res.status === 204;
}

export async function fetchMarketplaceCatalogFromApi(): Promise<string | null> {
  try {
    const res = await fetch(`${API_BASE}/v1/hub/marketplace-catalog`);
    if (!res.ok) return null;
    const data = await res.json();
    return JSON.stringify(data, null, 2);
  } catch {
    return null;
  }
}

export async function saveMarketplaceCatalogToApi(jsonText: string): Promise<boolean> {
  if (!hubApiConfigured()) return false;
  let parsed: unknown;
  try {
    parsed = JSON.parse(jsonText);
  } catch {
    return false;
  }
  const res = await fetch(`${API_BASE}/v1/hub/marketplace-catalog`, {
    method: 'PUT',
    headers: authHeaders(),
    body: JSON.stringify(parsed),
  });
  return res.ok || res.status === 204;
}

export type ArcadeUploadResult = {
  ok: boolean;
  id?: string;
  message?: string;
};

export async function uploadArcadeCart(file: File, meta: {
  title: string;
  cartId?: string;
  tags?: string;
  description?: string;
}): Promise<ArcadeUploadResult> {
  if (!hubApiConfigured()) {
    return { ok: false, message: 'Войдите как NEXUS или задайте VITE_HUB_ADMIN_TOKEN' };
  }
  const form = new FormData();
  form.append('cart', file);
  form.append('title', meta.title);
  if (meta.cartId) form.append('cartId', meta.cartId);
  if (meta.tags) form.append('tags', meta.tags);
  if (meta.description) form.append('description', meta.description);
  form.append('tier', 'free_to_play');

  const res = await fetch(`${API_BASE}/v1/arcade/carts`, {
    method: 'POST',
    headers: uploadHeaders(),
    body: form,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    return { ok: false, message: (data as { error?: string }).error ?? res.statusText };
  }
  return {
    ok: true,
    id: (data as { id?: string }).id,
    message: (data as { message?: string }).message ?? 'Опубликовано',
  };
}
