/** API Lynx на том же домене: /lynx → lynx-api (nginx). */
export function resolveLynxApiBase(): string {
  const raw =
    process.env.NEXT_PUBLIC_LYNX_API_BASE?.trim() ||
    process.env.NEXT_PUBLIC_NEXUS_API_BASE?.trim() ||
    '';
  if (raw && !/127\.0\.0\.1|localhost/i.test(raw)) {
    return raw.replace(/\/$/, '');
  }
  if (typeof window !== 'undefined') {
    return `${window.location.origin}/lynx`;
  }
  return '/lynx';
}

export const LYNX_API_BASE =
  typeof window !== 'undefined' ? resolveLynxApiBase() : process.env.NEXT_PUBLIC_LYNX_API_BASE || '/lynx';

export const NEXUS_API_BASE = LYNX_API_BASE;
