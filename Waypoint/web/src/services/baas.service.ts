import api from './api';

export interface BaasSchemaResponse {
  schema_name: string;
}

export interface DbQueryResponse {
  columns: string[];
  rows: Record<string, unknown>[];
}

export interface BaasBucket {
  id: string;
  name: string;
  public_read: boolean;
}

export interface BaasBootstrapResponse {
  schema_name: string;
  tables: string[];
  buckets: BaasBucket[];
}


export async function fetchBaasBootstrap(): Promise<BaasBootstrapResponse> {
  const { data } = await api.get<BaasBootstrapResponse>('/me/baas/bootstrap');
  return data;
}

export async function fetchBaasSchema(): Promise<BaasSchemaResponse> {
  const { data } = await api.get<BaasSchemaResponse>('/me/baas/schema');
  return data;
}

export async function runBaasSql(query: string): Promise<DbQueryResponse | { rows_affected: number }> {
  const { data } = await api.post<DbQueryResponse | { rows_affected: number }>('/me/baas/sql', { query });
  return data;
}

export async function listBaasTables(): Promise<string[]> {
  const { data } = await api.get<{ tables: string[] }>('/me/baas/tables');
  return data.tables;
}

export async function createBaasTable(name: string): Promise<void> {
  await api.post('/me/baas/tables', { name });
}

export async function listBaasRestRows(table: string): Promise<Record<string, unknown>[]> {
  const { data } = await api.get<{ rows: Record<string, unknown>[] }>(`/me/baas/rest/${encodeURIComponent(table)}`);
  return data.rows;
}

export async function insertBaasRow(table: string, data: Record<string, unknown>): Promise<unknown> {
  const { data: out } = await api.post(`/me/baas/rest/${encodeURIComponent(table)}`, data);
  return out;
}

export async function deleteBaasRow(table: string, id: string): Promise<void> {
  await api.delete(`/me/baas/rest/${encodeURIComponent(table)}/${id}`);
}

export async function listBuckets(): Promise<BaasBucket[]> {
  const { data } = await api.get<{ buckets: BaasBucket[] }>('/me/baas/buckets');
  return data.buckets;
}

export async function createBucket(name: string, publicRead = false): Promise<void> {
  await api.post('/me/baas/buckets', { name, public_read: publicRead });
}

export async function uploadBaasObject(bucket: string, key: string, file: File): Promise<void> {
  const fd = new FormData();
  fd.append('file', file);
  await api.put(`/me/baas/buckets/${encodeURIComponent(bucket)}/objects`, fd, {
    params: { key },
  });
}


export function baasPublicObjectUrl(ownerId: string, bucket: string, key: string): string {
  const base = api.defaults.baseURL ?? '';
  const q = new URLSearchParams({ key }).toString();
  return `${base}/waypointmetric/v1/storage/public/${ownerId}/${encodeURIComponent(bucket)}/objects?${q}`;
}

export async function downloadBaasObject(bucket: string, key: string): Promise<Blob> {
  const { data } = await api.get<Blob>(`/me/baas/buckets/${encodeURIComponent(bucket)}/objects`, {
    params: { key },
    responseType: 'blob',
  });
  return data;
}
