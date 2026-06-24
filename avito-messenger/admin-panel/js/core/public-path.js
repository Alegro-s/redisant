/** Subpath-aware base for admin panel (e.g. /yalgsi/admin/ behind nginx). */
export function resolveAdminBase() {
  if (typeof window !== "undefined" && window.NT_ADMIN_BASE) {
    return String(window.NT_ADMIN_BASE);
  }
  const path = typeof window !== "undefined" ? window.location.pathname || "" : "";
  const marker = "/admin";
  const i = path.indexOf(marker);
  if (i >= 0) return `${path.slice(0, i + marker.length)}/`;
  return "/admin/";
}

export function resolveApiBase() {
  if (typeof window !== "undefined" && window.NT_API_URL) {
    return String(window.NT_API_URL).replace(/\/$/, "");
  }
  if (typeof window !== "undefined" && window.NT_API_BASE) {
    return String(window.NT_API_BASE).replace(/\/$/, "");
  }
  const host = typeof window !== "undefined" ? window.location.host : "";
  const proto = typeof window !== "undefined" ? window.location.protocol : "";
  if (!host || !proto || proto === "file:") return "";
  const prefix = resolveAdminBase().replace(/\/admin\/$/, "");
  return `${proto}//${host}${prefix}`.replace(/\/$/, "");
}

export function adminEntryHint() {
  const base = resolveAdminBase().replace(/\/$/, "");
  return `${base}/?key=ВАШ_КЛЮЧ`;
}
