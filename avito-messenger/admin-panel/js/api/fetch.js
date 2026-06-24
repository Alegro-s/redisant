import { config } from "../config.js";

export function adminHeaders(extra = {}) {
  const headers = { ...extra };
  const key = config.adminKey;
  const session = config.sessionToken;
  if (key) headers["X-Admin-Key"] = key;
  if (session) headers["X-Admin-Session"] = session;
  return headers;
}

export function apiFetch(path, options = {}) {
  const headers = adminHeaders(options.headers || {});
  if (options.body && !headers["Content-Type"]) {
    headers["Content-Type"] = "application/json";
  }
  const timeoutMs = options.timeoutMs ?? 25000;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  const { timeoutMs: _t, signal: extSignal, ...rest } = options;
  if (extSignal) {
    extSignal.addEventListener("abort", () => ctrl.abort(), { once: true });
  }
  return fetch(`${config.apiUrl.replace(/\/$/, "")}${path}`, {
    ...rest,
    headers,
    signal: ctrl.signal,
  }).finally(() => clearTimeout(timer));
}
