
const KEY = 'waypoint_preferred_plan';

export type PreferredPlan = 'basic' | 'pro';

export function setPreferredPlan(plan: string | null): void {
  if (plan === 'basic' || plan === 'pro') {
    sessionStorage.setItem(KEY, plan);
  }
}


export function consumePreferredPlan(): PreferredPlan | null {
  const v = sessionStorage.getItem(KEY);
  sessionStorage.removeItem(KEY);
  if (v === 'basic' || v === 'pro') return v;
  return null;
}
