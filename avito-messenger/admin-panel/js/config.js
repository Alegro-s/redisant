import { adminEntryHint, resolveApiBase } from "./core/public-path.js";

function resolveApiUrl() {
  if (typeof window === "undefined") return "";
  if (window.NT_API_URL) return String(window.NT_API_URL).replace(/\/$/, "");

  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get("api");
  if (fromQuery) return fromQuery.replace(/\/$/, "");

  return resolveApiBase();
}

function resolveAdminKey() {
  if (typeof window === "undefined") return "";
  if (window.NT_ADMIN_KEY) return String(window.NT_ADMIN_KEY);
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get("key") || params.get("adminKey");
  if (fromQuery) {
    try {
      sessionStorage.setItem("nt_admin_key", fromQuery);
    } catch (_) {}
    return fromQuery;
  }
  try {
    return sessionStorage.getItem("nt_admin_key") || "";
  } catch (_) {
    return "";
  }
}

export function setAdminKey(key) {
  try {
    sessionStorage.setItem("nt_admin_key", key);
  } catch (_) {}
}

export function getSessionToken() {
  try {
    return sessionStorage.getItem("nt_admin_session") || "";
  } catch (_) {
    return "";
  }
}

export function setSessionToken(token) {
  try {
    if (token) sessionStorage.setItem("nt_admin_session", token);
    else sessionStorage.removeItem("nt_admin_session");
  } catch (_) {}
}

export const config = {
  get apiUrl() {
    return resolveApiUrl();
  },
  get adminKey() {
    return resolveAdminKey();
  },
  get sessionToken() {
    return getSessionToken();
  },
  get adminEntryHint() {
    return adminEntryHint();
  },
  pollMs: 20_000,
};
