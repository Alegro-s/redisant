
export const LYNX_API_BASE =
  process.env.NEXT_PUBLIC_LYNX_API_BASE ??
  process.env.NEXT_PUBLIC_NEXUS_API_BASE ??
  'http://127.0.0.1:8080';


export const NEXUS_API_BASE = LYNX_API_BASE;
