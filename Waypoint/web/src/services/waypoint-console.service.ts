import api from './api';

export interface WaypointApiKey {
  id: string;
  user_id: string;
  name: string;
  
  key_masked: string;
  last_used: string | null;
  created_at: string;
}

export interface WaypointUsageDay {
  day: string;
  metrics: number;
  logs: number;
}

export interface WaypointKeyUsageRow {
  id: string;
  name: string;
  last_used: string | null;
  created_at: string;
  metrics_30d: number;
  logs_30d: number;
  dev_events_30d: number;
}

export interface WaypointUsageResponse {
  window_days: number;
  totals: { metrics: number; logs: number; dev_events: number };
  by_day: WaypointUsageDay[];
  by_api_key: WaypointKeyUsageRow[];
  quotas: {
    metrics_per_month_soft_cap: number;
    log_lines_per_month_soft_cap: number;
    ingest_rpm_per_api_key_cap: number;
    note: string;
  };
}

export async function listWaypointApiKeys(): Promise<WaypointApiKey[]> {
  const { data } = await api.get<WaypointApiKey[]>('/api/waypoint/api-keys');
  return data;
}

export async function createWaypointApiKey(name: string): Promise<{ id: string; key: string; name: string }> {
  const { data } = await api.post<{ id: string; key: string; name: string }>('/api/waypoint/api-keys', { name });
  return data;
}

export async function patchWaypointApiKey(id: string, name: string): Promise<WaypointApiKey> {
  const { data } = await api.patch<WaypointApiKey>(`/api/waypoint/api-keys/${id}`, { name });
  return data;
}

export async function deleteWaypointApiKey(id: string): Promise<void> {
  await api.delete(`/api/waypoint/api-keys/${id}`);
}

export async function fetchWaypointUsage(): Promise<WaypointUsageResponse> {
  const { data } = await api.get<WaypointUsageResponse>('/me/waypoint/usage');
  return data;
}

