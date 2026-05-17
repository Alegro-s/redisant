import api from './api';

export interface AiQuotaResponse {
  plan: string;
  utc_date: string;
  business: { used: number; limit: number };
  developer: { used: number; limit: number };
}

export async function fetchAiQuota(): Promise<AiQuotaResponse> {
  const { data } = await api.get<AiQuotaResponse>('/me/ai/quota');
  return data;
}

export interface VoucherDto {
  id: string;
  user_id: string;
  code: string;
  campaign: string;
  redeem_limit: number;
  redeemed: number;
  created_at: string;
  updated_at: string;
}

export async function listVouchers(): Promise<VoucherDto[]> {
  const { data } = await api.get<{ items: VoucherDto[] }>('/me/vouchers');
  return data.items ?? [];
}

export async function createVoucher(body: {
  code: string;
  campaign?: string;
  redeem_limit?: number;
  redeemed?: number;
}): Promise<VoucherDto> {
  const { data } = await api.post<VoucherDto>('/me/vouchers', body);
  return data;
}

export async function patchVoucher(
  id: string,
  body: Partial<Pick<VoucherDto, 'code' | 'campaign' | 'redeem_limit' | 'redeemed'>>,
): Promise<VoucherDto> {
  const { data } = await api.patch<VoucherDto>(`/me/vouchers/${id}`, body);
  return data;
}

export async function deleteVoucher(id: string): Promise<void> {
  await api.delete(`/me/vouchers/${id}`);
}

export interface ShipmentDto {
  id: string;
  user_id: string;
  external_ref: string;
  route: string;
  status: string;
  carrier: string;
  meta: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export async function listShipments(): Promise<ShipmentDto[]> {
  const { data } = await api.get<{ items: ShipmentDto[] }>('/me/shipments');
  return data.items ?? [];
}

export async function createShipment(body: {
  external_ref?: string;
  route?: string;
  status?: string;
  carrier?: string;
  meta?: Record<string, unknown>;
}): Promise<ShipmentDto> {
  const { data } = await api.post<ShipmentDto>('/me/shipments', body);
  return data;
}

export async function patchShipment(
  id: string,
  body: Partial<Pick<ShipmentDto, 'external_ref' | 'route' | 'status' | 'carrier' | 'meta'>>,
): Promise<ShipmentDto> {
  const { data } = await api.patch<ShipmentDto>(`/me/shipments/${id}`, body);
  return data;
}

export async function deleteShipment(id: string): Promise<void> {
  await api.delete(`/me/shipments/${id}`);
}
