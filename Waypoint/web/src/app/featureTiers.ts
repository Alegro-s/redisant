import type { PlanCode } from './contexts/WorkspaceContext';


export type PaidFeature =
  | 'vouchers_bulk'
  | 'tax_exports'
  | 'logistics_webhooks'
  | 'documents_templates_pack'
  | 'erp_multi_warehouse';

export function hasPaidFeature(plan: PlanCode, feature: PaidFeature): boolean {
  if (plan === 'pro') return true;
  return false;
}
