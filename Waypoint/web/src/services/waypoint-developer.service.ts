import api from './api';

export const WAYPOINT_DEV_EVENT_CHANNELS = [
  'performance',
  'brandformance',
  'smm',
  'reputation',
  'analytics',
  'web_dev',
  'design',
  'storage',
] as const;

export type WaypointDevEventChannel = (typeof WAYPOINT_DEV_EVENT_CHANNELS)[number];

export interface WaypointDevEvent {
  id: number;
  api_key_id: string;
  channel: string;
  event_name: string;
  value: number | null;
  properties: unknown;
  timestamp: string;
}

export interface WaypointNetworkDrive {
  id: string;
  owner_id: string;
  name: string;
  protocol: string;
  endpoint_uri: string;
  path_prefix: string;
  meta: unknown;
  created_at: string;
  updated_at: string;
}

export async function listWaypointDeveloperEvents(params?: {
  limit?: number;
  channel?: string;
}): Promise<WaypointDevEvent[]> {
  const { data } = await api.get<{ items: WaypointDevEvent[] }>('/api/waypoint/developer-events', {
    params: {
      limit: params?.limit ?? 100,
      channel: params?.channel || undefined,
    },
  });
  return data.items;
}

export async function listWaypointNetworkDrives(): Promise<WaypointNetworkDrive[]> {
  const { data } = await api.get<{ items: WaypointNetworkDrive[] }>('/api/waypoint/network-drives');
  return data.items;
}

export async function createWaypointNetworkDrive(body: {
  name: string;
  protocol: string;
  endpoint_uri: string;
  path_prefix?: string;
  meta?: unknown;
}): Promise<WaypointNetworkDrive> {
  const { data } = await api.post<WaypointNetworkDrive>('/api/waypoint/network-drives', body);
  return data;
}

export async function patchWaypointNetworkDrive(
  id: string,
  body: Partial<{
    name: string;
    protocol: string;
    endpoint_uri: string;
    path_prefix: string;
    meta: unknown;
  }>,
): Promise<WaypointNetworkDrive> {
  const { data } = await api.patch<WaypointNetworkDrive>(`/api/waypoint/network-drives/${id}`, body);
  return data;
}

export async function deleteWaypointNetworkDrive(id: string): Promise<void> {
  await api.delete(`/api/waypoint/network-drives/${id}`);
}
